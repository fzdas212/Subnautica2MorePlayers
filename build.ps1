param(
    [string]$ProjectRoot = $PSScriptRoot
)

$ErrorActionPreference = "Stop"

$modName = "Subnautica2MorePlayers8"
$src = Join-Path $ProjectRoot "src\MorePlayers8"
$dist = Join-Path $ProjectRoot "dist\$modName"
$config = Join-Path $ProjectRoot "MorePlayers8.json"
$nativeSource = Join-Path $src "native\MorePlayers8Native.cpp"
$nativeOutDir = Join-Path $dist "native"
$nativeDll = Join-Path $nativeOutDir "MorePlayers8Native.dll"

if (-not (Test-Path -LiteralPath $src)) {
    throw "Missing source directory: $src"
}
if (-not (Test-Path -LiteralPath $config)) {
    throw "Missing config file: $config"
}

$parsed = Get-Content -LiteralPath $config -Raw | ConvertFrom-Json
if ($parsed.MaxPlayers -lt 1 -or $parsed.MaxPlayers -gt 64) {
    throw "MaxPlayers must be between 1 and 64."
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
Copy-Item -Path (Join-Path $src "*") -Destination $dist -Recurse -Force
Copy-Item -LiteralPath $config -Destination (Join-Path $dist "MorePlayers8.json") -Force

if (Test-Path -LiteralPath $nativeSource) {
    $cl = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.43.34808\bin\Hostx64\x64\cl.exe"
    $include = "C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\um"
    $sharedInclude = "C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\shared"
    $ucrtInclude = "C:\Program Files (x86)\Windows Kits\10\Include\10.0.22621.0\ucrt"
    $msvcInclude = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.43.34808\include"
    $lib = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\um\x64"
    $ucrtLib = "C:\Program Files (x86)\Windows Kits\10\Lib\10.0.22621.0\ucrt\x64"
    $msvcLib = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.43.34808\lib\x64"

    if (-not (Test-Path -LiteralPath $cl)) {
        throw "cl.exe not found: $cl"
    }

    New-Item -ItemType Directory -Force -Path $nativeOutDir | Out-Null
    & $cl /nologo /std:c++17 /EHsc /O2 /LD /DUNICODE /D_UNICODE `
        "/I$include" "/I$sharedInclude" "/I$ucrtInclude" "/I$msvcInclude" `
        $nativeSource /Fe:$nativeDll /link "/LIBPATH:$lib" "/LIBPATH:$ucrtLib" "/LIBPATH:$msvcLib" bcrypt.lib
    if ($LASTEXITCODE -ne 0) {
        throw "Native build failed with cl.exe exit code $LASTEXITCODE"
    }
}

$meta = [ordered]@{
    ModName = $modName
    BuiltAt = (Get-Date).ToString("o")
    Source = $src
    Config = $config
}
$meta | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $dist "build_manifest.json") -Encoding UTF8

Write-Host "Built $modName to $dist"
