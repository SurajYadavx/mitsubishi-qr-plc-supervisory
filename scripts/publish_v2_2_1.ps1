$ErrorActionPreference = 'Stop'

$Owner = 'SurajYadavx'
$Repository = 'mitsubishi-qr-plc-supervisory'
$RepositoryFullName = "$Owner/$Repository"
$RepositoryUrl = "https://github.com/$RepositoryFullName.git"
$CreateUrl = "https://github.com/new?name=$Repository&visibility=public"

Write-Host "Project V2.2.1 clean GitHub publisher" -ForegroundColor Cyan
Write-Host "Target: $RepositoryUrl"
Write-Host "The existing mitsubishi-q-plc-app repository will not be modified."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is not installed or not available in PATH. Install Git for Windows and reopen PowerShell.'
}
if (Test-Path '.git') {
    throw 'This folder already contains .git. Extract the publish-ready ZIP into a new clean folder and run this script there.'
}

$ForbiddenFiles = Get-ChildItem -Recurse -File -Force | Where-Object {
    $_.Name -match '^(secrets\.h|ca_cert\.h|\.env(?:\..*)?|secrets\.ini)$' -or
    $_.Extension -in @('.key', '.pem', '.p12', '.pfx', '.crt', '.cer', '.der', '.p8', '.ppk', '.jks') -or
    $_.FullName -match '[\\/](\.venv|venv|node_modules|\.pio|__pycache__)[\\/]'
}
if ($ForbiddenFiles) {
    $ForbiddenFiles | ForEach-Object { Write-Host "Blocked: $($_.FullName)" -ForegroundColor Red }
    throw 'Potential secret or local build artifact found. Do not publish until reviewed.'
}

Write-Host ''
Write-Host 'The public repository exposes source code and documentation. Actual credentials must stay in the untracked secrets.h file.' -ForegroundColor Yellow
$Answer = Read-Host 'Type PUBLISH to prepare and publish this release to the separate public repository'
if ($Answer -cne 'PUBLISH') { throw 'Cancelled. No Git repository was initialized and nothing was pushed.' }

git init -b main
if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }

$Staged = git diff --cached --name-only
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect staged files.' }
$StagedForbidden = $Staged | Where-Object {
    $_ -match '(^|/)(secrets\.h|ca_cert\.h|\.env(?:\..*)?|secrets\.ini)$' -or
    $_ -match '\.(key|pem|p12|pfx|crt|cer|der|p8|ppk|jks)$'
}
if ($StagedForbidden) {
    $StagedForbidden | ForEach-Object { Write-Host "Blocked staged file: $_" -ForegroundColor Red }
    throw 'A sensitive file is staged. Nothing has been pushed.'
}

git commit -m 'Release Project V2.2.1 dual-PLC local supervisory system'
if ($LASTEXITCODE -ne 0) { throw 'git commit failed. Configure Git user.name and user.email, then retry.' }

$GhAvailable = [bool](Get-Command gh -ErrorAction SilentlyContinue)
$GhAuthenticated = $false
if ($GhAvailable) {
    gh auth status --hostname github.com *> $null
    $GhAuthenticated = ($LASTEXITCODE -eq 0)
}

if ($GhAuthenticated) {
    gh repo view $RepositoryFullName *> $null
    if ($LASTEXITCODE -eq 0) {
        throw "Repository $RepositoryFullName already exists. Script stopped to avoid writing into an existing or non-empty repository. Inspect it manually and choose a new name if needed."
    }
    Write-Host "Creating the new public repository $RepositoryFullName with GitHub CLI..." -ForegroundColor Cyan
    gh repo create $RepositoryFullName --public --source . --remote origin --push
    if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI repository creation or push failed. Check gh auth status and GitHub permissions.' }
} else {
    Write-Host 'GitHub CLI is unavailable or not signed in. Opening the GitHub new-repository page.' -ForegroundColor Yellow
    Start-Process $CreateUrl
    Write-Host 'Create a PUBLIC repository named mitsubishi-qr-plc-supervisory. Do not add a README, licence or .gitignore; this release already includes them.' -ForegroundColor Yellow
    Read-Host 'After creating the EMPTY repository, press Enter to continue'
    git remote add origin $RepositoryUrl
    if ($LASTEXITCODE -ne 0) { throw 'Could not add the origin remote.' }
    git push -u origin main
    if ($LASTEXITCODE -ne 0) { throw 'Push failed. Check the new repository is empty and complete GitHub authentication. Do not use --force.' }
}

Write-Host ''
Write-Host 'Release source pushed successfully.' -ForegroundColor Green
Write-Host 'Next: GitHub > Settings > Pages > Build and deployment > Source: GitHub Actions.'
Write-Host 'Then confirm the Deploy Project V2.2.1 to GitHub Pages workflow succeeds.'
Write-Host 'Expected URL: https://surajyadavx.github.io/mitsubishi-qr-plc-supervisory/'
