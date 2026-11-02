# Windows PowerShell 5.1. Uses installed Windows desktop speech recognition.
# Does not download models, use cloud speech APIs or evaluate spoken code.
param([Parameter(Mandatory=$true)][string]$SessionPath)
$ErrorActionPreference = 'Stop'
$recognizer = $null
$subscription = $null
function Set-Status([string]$Text) {
    [IO.File]::WriteAllText($SessionPath + '.status', $Text, [Text.Encoding]::UTF8)
}
try {
    Add-Type -AssemblyName System.Speech
    $installed = @([System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers())
    $locale = $installed | Where-Object { $_.Culture.Name -eq 'pt-BR' } | Select-Object -First 1
    if (-not $locale) { Set-Status 'missing-locale'; exit 2 }
    $recognizer = New-Object -TypeName System.Speech.Recognition.SpeechRecognitionEngine -ArgumentList $locale
    $commands = @{
        'selecionar processo' = 'process'; 'primeira busca' = 'scan';
        'próxima busca' = 'next'; 'abrir tabela' = 'table';
        'abrir memória' = 'memory'; 'abrir scripts' = 'scripts';
        'abrir ajuda' = 'help'; 'parar escuta' = 'stop';
        'interface original' = 'original'
    }
    $choices = New-Object System.Speech.Recognition.Choices
    foreach ($phrase in $commands.Keys) { $choices.Add([string]$phrase) }
    $builder = New-Object System.Speech.Recognition.GrammarBuilder
    $builder.Culture = $locale.Culture
    $builder.Append($choices)
    $grammar = New-Object System.Speech.Recognition.Grammar($builder)
    $recognizer.LoadGrammar($grammar)
    $recognizer.SetInputToDefaultAudioDevice()
    $state = @{ Path = $SessionPath; Commands = $commands; Sequence = 0 }
    $subscription = Register-ObjectEvent -InputObject $recognizer -EventName SpeechRecognized -MessageData $state -Action {
        $speech = $Event.SourceEventArgs.Result
        $state = $Event.MessageData
        if ($speech.Confidence -ge 0.80 -and $state.Commands.ContainsKey($speech.Text)) {
            $state.Sequence++
            $line = '{0}|{1}' -f $state.Sequence, $state.Commands[$speech.Text]
            [IO.File]::AppendAllText($state.Path + '.events', $line + "`n", [Text.Encoding]::ASCII)
        }
    }
    $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
    Set-Status 'ready'
    $deadline = [DateTime]::UtcNow.AddHours(2)
    while (-not [IO.File]::Exists($SessionPath + '.stop') -and [DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 200
    }
    Set-Status 'stopped'
} catch {
    Set-Status 'error'
    exit 1
} finally {
    if ($recognizer) { $recognizer.RecognizeAsyncCancel() }
    if ($subscription) {
        Unregister-Event -SourceIdentifier $subscription.Name -ErrorAction SilentlyContinue
        Remove-Job -Id $subscription.Id -Force -ErrorAction SilentlyContinue
    }
    if ($recognizer) { $recognizer.Dispose() }
}
