$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
$audioRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../assets/audio'))
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
$speaker.SelectVoice('Microsoft Maria Desktop')
$speaker.Rate = 0
$lines = [ordered]@{
    round_one = 'Primeiro round!'
    round_two = 'Segundo round!'
    final_round = 'Round final!'
    fight = 'Lutem!'
    ko = 'Nocaute!'
    perfect = 'Vitória perfeita!'
    counter = 'Contra ataque!'
    guard_break_voice = 'Guarda quebrada!'
    final_hit = 'Golpe final!'
    player_one_wins = 'Jogador um vence!'
    player_two_wins = 'Jogador dois vence!'
}
try {
    foreach ($entry in $lines.GetEnumerator()) {
        $speaker.SetOutputToWaveFile((Join-Path $audioRoot ('voice_' + $entry.Key + '.wav')))
        $speaker.Speak($entry.Value)
        $speaker.SetOutputToNull()
    }
} finally { $speaker.Dispose() }
Write-Output 'Narrador em português gerado.'
