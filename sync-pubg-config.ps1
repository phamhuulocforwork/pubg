param(
    [string]$Branch = "main",
    [string[]]$ExcludeFiles = @("README.md", "LICENSE", ".gitignore", "sync-pubg-config.ps1"),

    # ==== Cấu hình phần tải mod mới nhất ====
    [string[]]$UgcModIds = @(
        "1642181",   # Training mode
        "1652500"    # Training by Ermaak v2
    ),
    [string]$UgcDir = (Join-Path $env:LOCALAPPDATA "TslGame\Saved\UGC")
)

$ErrorActionPreference = "Stop"

$Owner   = "phamhuulocforwork"
$Repo    = "pubg"
$SubPath = ""

$ConfigDir = Join-Path $env:LOCALAPPDATA "TslGame\Saved\Config\WindowsNoEditor"
$BackupDir = Join-Path $env:LOCALAPPDATA ("TslGame\Saved\Config\WindowsNoEditor_backup_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
$ApiBase   = "https://api.github.com/repos/$Owner/$Repo/contents"

function Get-RepoFiles {
    param([string]$Path)
    $url = if ($Path) { "$ApiBase/$Path`?ref=$Branch" } else { "$ApiBase`?ref=$Branch" }
    $items = Invoke-RestMethod -Uri $url -Headers @{ "User-Agent" = "pubg-config-sync" }
    foreach ($item in $items) {
        if ($item.type -eq "dir") {
            Get-RepoFiles -Path $item.path
        } elseif ($ExcludeFiles -notcontains $item.name) {
            [PSCustomObject]@{
                RepoPath = $item.path
                RawUrl   = $item.download_url
            }
        }
    }
}

function Get-LatestCurseForgeFile {
    param([Parameter(Mandatory)][string]$ModId)

    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) pubg-config-sync"
        "Accept"     = "application/json"
    }
    $url = "https://www.curseforge.com/api/v1/mods/$ModId/files"
    $resp = Invoke-RestMethod -Uri $url -Headers $headers

    if (-not $resp.data) {
        throw "Không lấy được danh sách file cho ModId=$ModId"
    }

    # Sắp theo ngày mới nhất
    $latest = $resp.data | Sort-Object -Property dateModified -Descending | Select-Object -First 1
    return $latest
}

function Save-LatestCurseForgeFile {
    param(
        [Parameter(Mandatory)][string]$ModId,
        [Parameter(Mandatory)][string]$DestDir
    )

    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) pubg-config-sync"
    }

    Write-Host "==> Đang kiểm tra file mới nhất trên CurseForge (ModId=$ModId)..." -ForegroundColor Cyan
    $latest = Get-LatestCurseForgeFile -ModId $ModId

    $fileId   = $latest.id
    $fileName = $latest.fileName
    Write-Host "  - File mới nhất: $fileName (id=$fileId, ngày $($latest.dateModified))"

    if (-not (Test-Path $DestDir)) {
        New-Item -ItemType Directory -Path $DestDir -Force | Out-Null
    }

    $destPath = Join-Path $DestDir $fileName
    $downloadUrl = "https://www.curseforge.com/api/v1/mods/$ModId/files/$fileId/download"

    Write-Host "  - Tải về: $destPath"
    Invoke-WebRequest -Uri $downloadUrl -Headers $headers -OutFile $destPath

    Write-Host "==> Xong! File mod đã nằm ở: $destPath" -ForegroundColor Green
}

# ============ 1. Đồng bộ config từ GitHub ============
Write-Host "==> Lấy danh sách file từ $Owner/$Repo ($SubPath, branch $Branch)..." -ForegroundColor Cyan
$files = Get-RepoFiles -Path $SubPath

if (-not $files) {
    Write-Host "Không tìm thấy file nào trong '$SubPath'. Kiểm tra lại Owner/Repo/Branch/SubPath." -ForegroundColor Red
    exit 1
}

if (Test-Path $ConfigDir) {
    Write-Host "==> Backup config hiện tại vào: $BackupDir" -ForegroundColor Yellow
    Copy-Item -Path $ConfigDir -Destination $BackupDir -Recurse
} else {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

foreach ($f in $files) {
    $relative = $f.RepoPath
    $destPath = Join-Path $ConfigDir $relative
    $destDir  = Split-Path $destPath -Parent

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    Write-Host "  - Tải: $relative"
    Invoke-WebRequest -Uri $f.RawUrl -OutFile $destPath
}

Write-Host "`n==> Xong! Config đã được đồng bộ vào:`n$ConfigDir" -ForegroundColor Green
Write-Host "==> Bản backup cũ (nếu có) nằm ở:`n$BackupDir" -ForegroundColor Green

# ============ 2. Tải các file mod mới nhất từ CurseForge ============
foreach ($modId in $UgcModIds) {
    try {
        Save-LatestCurseForgeFile -ModId $modId -DestDir $UgcDir
    } catch {
        Write-Host "Lỗi khi tải mod (ModId=$modId) từ CurseForge: $_" -ForegroundColor Red
    }
}