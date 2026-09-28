$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $IsWindows) { throw 'Build PrismArt for Windows on a Windows machine or GitHub Actions Windows runner.' }
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$version = if ($env:VERSION) { $env:VERSION.TrimStart('v') } else { (Get-Content VERSION -Raw).Trim() }
if ($version -notmatch '^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$') { throw "Invalid version: $version" }

$upstream = Join-Path $root '.build/upstream/primitive'
$publish = Join-Path $root 'dist/windows'
New-Item -ItemType Directory -Force (Split-Path -Parent $upstream) | Out-Null
New-Item -ItemType Directory -Force $publish | Out-Null
if (-not (Test-Path (Join-Path $upstream '.git'))) {
    git clone https://github.com/fogleman/primitive.git $upstream
    if ($LASTEXITCODE -ne 0) { throw 'Could not clone the Primitive engine.' }
}
$ref = if ($env:PRIMITIVE_REF) { $env:PRIMITIVE_REF } else { 'master' }
git -C $upstream fetch --depth 1 origin $ref
if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the Primitive engine.' }
git -C $upstream checkout --detach FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw 'Could not check out the Primitive engine.' }

Push-Location $upstream
try {
    if (-not (Test-Path go.mod)) {
        go mod init github.com/fogleman/primitive
        if ($LASTEXITCODE -ne 0) { throw 'Could not initialize Primitive Go module.' }
    }
    go mod tidy
    if ($LASTEXITCODE -ne 0) { throw 'Could not resolve Primitive Go dependencies.' }
    $env:CGO_ENABLED = '0'
    go build -trimpath '-ldflags=-s -w' -o (Join-Path $publish 'primitive.exe') .
    if ($LASTEXITCODE -ne 0) { throw 'Could not build primitive.exe.' }
} finally { Pop-Location }

dotnet publish Windows/PrismArt.Windows/PrismArt.Windows.csproj -c Release -r win-x64 --self-contained true -o $publish
if ($LASTEXITCODE -ne 0) { throw 'Could not publish PrismArt.exe.' }
Copy-Item LICENSE (Join-Path $publish 'LICENSE.txt')
Copy-Item Windows/README-Windows.txt (Join-Path $publish 'README-Windows.txt')
Copy-Item (Join-Path $upstream 'LICENSE.md') (Join-Path $publish 'Primitive-LICENSE.md')
git -C $upstream rev-parse HEAD | Set-Content (Join-Path $publish 'Primitive-REVISION.txt')

$zip = Join-Path $root "dist/PrismArt-$version-Windows-x64.zip"
Compress-Archive -Path (Join-Path $publish '*') -DestinationPath $zip -Force
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $(Split-Path -Leaf $zip)" | Set-Content -Encoding ascii "$zip.sha256"
Write-Host "Windows package: $zip"
