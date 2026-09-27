param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string]$WindowsReleaseTemplate = '',
    [string]$SignedRuntime = '',
    [string]$Output = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
if (-not $Output) { $Output = Join-Path (Split-Path -Parent $projectRoot) 'Windows\UFNCombate.exe' }
$outputPath = [IO.Path]::GetFullPath($Output)
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outputPath) | Out-Null
$presetPath = Join-Path $projectRoot 'export_presets.cfg'
$originalPreset = [IO.File]::ReadAllText($presetPath)
try {
    if ($WindowsReleaseTemplate) {
        $templatePath = (Resolve-Path -LiteralPath $WindowsReleaseTemplate).Path.Replace('\','/')
        $customPreset = $originalPreset.Replace('custom_template/release=""', 'custom_template/release="' + $templatePath + '"')
        [IO.File]::WriteAllText($presetPath, $customPreset, [Text.UTF8Encoding]::new($false))
    }
    & $enginePath --headless --path $projectRoot --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Falha na importação do projeto.' }
    if ($SignedRuntime) {
        $runtimePath = (Resolve-Path -LiteralPath $SignedRuntime).Path
        if ((Get-AuthenticodeSignature -LiteralPath $runtimePath).Status -ne 'Valid') { throw 'O runtime deve ter assinatura Authenticode válida.' }
        $packPath = [IO.Path]::ChangeExtension($outputPath, '.pck')
        & $enginePath --headless --path $projectRoot --export-pack 'Windows Desktop' $packPath
        if ($LASTEXITCODE -ne 0) { throw 'Falha ao exportar dados do jogo.' }
        Copy-Item -LiteralPath $runtimePath -Destination $outputPath -Force
    } else {
        & $enginePath --headless --path $projectRoot --export-release 'Windows Desktop' $outputPath
    }
    if ($LASTEXITCODE -ne 0) { throw 'Falha na exportação Windows.' }
    if (-not (Test-Path -LiteralPath $outputPath)) { throw 'Executável não encontrado.' }
    Write-Host "Build criada: $outputPath"
} finally {
    [IO.File]::WriteAllText($presetPath, $originalPreset, [Text.UTF8Encoding]::new($false))
}
