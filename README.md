```powershell
$u = "https://api.github.com/repos/phamhuulocforwork/pubg/contents/sync-pubg-config.ps1"
irm $u -Headers @{ Accept = "application/vnd.github.raw" } | iex
```