param(
    [string]$DumpPath = "D:\SteamLibrary\steamapps\common\Subnautica2\Subnautica2\Binaries\Win64\ue4ss\crash_2026_05_15_23_51_31.6512637.dmp",
    [string]$GameRoot = "D:\SteamLibrary\steamapps\common\Subnautica2",
    [string]$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path,
    [string]$OutPath = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $DumpPath)) {
    throw "Dump not found: $DumpPath"
}

$toolSource = Join-Path $PSScriptRoot "analyze_dump.cpp"
$toolExe = Join-Path $PSScriptRoot "analyze_dump.exe"
$shippingDir = Join-Path $GameRoot "Subnautica2\Binaries\Win64"
$symbolRoot = Join-Path $shippingDir "ue4ss"

if (-not (Test-Path -LiteralPath $toolSource)) {
    throw "Missing source: $toolSource"
}
if (-not (Test-Path -LiteralPath (Join-Path $symbolRoot "UE4SS.pdb"))) {
    throw "UE4SS.pdb not found under: $symbolRoot"
}

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

if (-not (Test-Path -LiteralPath $toolExe -PathType Leaf) -or
    (Get-Item -LiteralPath $toolExe).LastWriteTimeUtc -lt (Get-Item -LiteralPath $toolSource).LastWriteTimeUtc) {
    & $cl /nologo /std:c++17 /EHsc /W4 /DUNICODE /D_UNICODE `
        "/I$include" "/I$sharedInclude" "/I$ucrtInclude" "/I$msvcInclude" `
        $toolSource /Fe:$toolExe /link "/LIBPATH:$lib" "/LIBPATH:$ucrtLib" "/LIBPATH:$msvcLib" dbghelp.lib | Write-Host
}

if ($OutPath -eq "") {
    $docs = Join-Path $ProjectRoot "docs"
    New-Item -ItemType Directory -Force -Path $docs | Out-Null
    $name = [IO.Path]::GetFileNameWithoutExtension($DumpPath)
    $OutPath = Join-Path $docs "$name.analysis.md"
}

$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $DumpPath).Hash
$analysis = & $toolExe $DumpPath $symbolRoot
$header = @(
    "# Crash Dump Analysis",
    "",
    "- Dump: ``$DumpPath``",
    "- SHA256: ``$hash``",
    "- Generated: ``$((Get-Date).ToString("o"))``",
    ""
) -join "`r`n"

Set-Content -LiteralPath $OutPath -Value ($header + ($analysis -join "`r`n") + "`r`n") -Encoding UTF8
Write-Host "Wrote dump analysis to $OutPath"
