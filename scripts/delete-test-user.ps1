# Usage: .\scripts\delete-test-user.ps1 support@handalstay.com
param([string]$Email)

if (-not $Email) {
    Write-Host "Usage: .\scripts\delete-test-user.ps1 <email>" -ForegroundColor Yellow
    exit 1
}

$findSql = "SELECT id FROM auth.users WHERE email = '$Email';"
$result = npx supabase db query --remote --yes $findSql 2>&1 | Out-String

if ($result -notmatch '"id"') {
    Write-Host "Not found: $Email" -ForegroundColor Yellow
    exit 0
}

# Extract UUID from JSON output
$uuid = [regex]::Match($result, '"id"\s*:\s*"([0-9a-f-]{36})"').Groups[1].Value
if (-not $uuid) {
    Write-Host "Could not parse UUID from result:" -ForegroundColor Red
    Write-Host $result
    exit 1
}

Write-Host "Deleting $Email ($uuid)..." -ForegroundColor Cyan
$delSql = "DELETE FROM businesses WHERE owner_id = '$uuid'; DELETE FROM auth.users WHERE id = '$uuid';"
npx supabase db query --remote --yes $delSql
Write-Host "Done." -ForegroundColor Green
