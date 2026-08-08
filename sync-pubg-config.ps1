param(
    [string]$Branch = "main",
    [string[]]$ExcludeFiles = @("README.md", "LICENSE", ".gitignore", "sync-pubg-config.ps1")
)

$ErrorActionPreference = "Stop"

$Owner   = "phamhuulocforwork"
$Repo    = "pubg"
$SubPath = ""   # file config nằm ngay ở root repo, không có thư mục con

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
    # Files nằm ngay ở root repo -> RepoPath chính là đường dẫn tương đối
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