param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$importLog = & $enginePath --headless --path $projectRoot --editor --import --quit 2>&1
$importLog | Write-Output
if ($LASTEXITCODE -ne 0 -or ($importLog -join "`n") -match 'SCRIPT ERROR:|ERROR:') { throw 'Falha na importação.' }
foreach ($test in @('ufn_combat_test.gd','modules_test.gd','audio_test.gd','defense_test.gd','data_test.gd','flow_test.gd','test_kart.gd','v2_test.gd','release_test.gd')) {
    $testLog = & $enginePath --headless --path $projectRoot --script "res://tests/$test" 2>&1
    $testLog | Write-Output
    if ($LASTEXITCODE -ne 0 -or ($testLog -join "`n") -match 'SCRIPT ERROR:|ERROR:') { throw "Falha: $test" }
}
