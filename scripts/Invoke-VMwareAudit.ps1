[CmdletBinding()]
param(
    [string]$InputPath,
    [string]$ConfigPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$radiceProgetto = Split-Path -Parent $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $InputPath = Join-Path $radiceProgetto 'sample-data'
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $radiceProgetto 'config/audit-config.example.json'
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $radiceProgetto 'reports'
}

$percorsoModulo = Join-Path $radiceProgetto 'modules/VMwareAudit.Core.psm1'
Import-Module -Name $percorsoModulo -Force

$fileRichiesti = [ordered]@{
    MacchineVirtuali = Join-Path $InputPath 'vInfo.csv'
    Snapshot         = Join-Path $InputPath 'vSnapshot.csv'
    Datastore        = Join-Path $InputPath 'vDatastore.csv'
}

foreach ($fileRichiesto in $fileRichiesti.GetEnumerator()) {
    if (-not (Test-Path -LiteralPath $fileRichiesto.Value -PathType Leaf)) {
        throw "File di input obbligatorio non trovato: $($fileRichiesto.Value)"
    }
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "File di configurazione non trovato: $ConfigPath"
}

$configurazione = Get-Content -LiteralPath $ConfigPath -Raw |
    ConvertFrom-Json

$macchineVirtuali = @(
    Import-Csv -LiteralPath $fileRichiesti.MacchineVirtuali
)

$snapshot = @(
    Import-Csv -LiteralPath $fileRichiesti.Snapshot
)

$datastore = @(
    Import-Csv -LiteralPath $fileRichiesti.Datastore
)

# Eseguire i controlli soltanto sulle raccolte non vuote.
# Un inventario senza snapshot non deve causare un errore.
$risultati = @(
    if ($snapshot.Count -gt 0) {
        Get-SnapshotAuditFinding -Snapshot $snapshot -Configurazione $configurazione
    }

    if ($datastore.Count -gt 0) {
        Get-DatastoreAuditFinding -Datastore $datastore -Configurazione $configurazione
    }

    if ($macchineVirtuali.Count -gt 0) {
        Get-VMwareToolsAuditFinding -MacchineVirtuali $macchineVirtuali

        Get-VirtualHardwareAuditFinding -MacchineVirtuali $macchineVirtuali -Configurazione $configurazione
    }
)

$ordineGravita = @{
    Critico     = 1
    Alto        = 2
    Medio       = 3
    Basso       = 4
    Informativo = 5
}

$criteriOrdinamento = @(
    @{ Expression = { $ordineGravita[$_.Gravita] } }
    'Categoria'
    'Oggetto'
)

$risultati = @(
    $risultati | Sort-Object -Property $criteriOrdinamento
)

$dataEsecuzione = Get-Date
$nomeDirectory = $dataEsecuzione.ToString('yyyyMMdd-HHmmss-fff')
$directoryEsecuzione = Join-Path $OutputPath $nomeDirectory

# Senza -Force: una directory gia esistente non viene riutilizzata.
New-Item -ItemType Directory -Path $directoryEsecuzione |
    Out-Null

$percorsoAnomalie = Join-Path $directoryEsecuzione 'findings.csv'
$percorsoRiepilogo = Join-Path $directoryEsecuzione 'summary.json'

if ($risultati.Count -gt 0) {
    $risultati |
        Export-Csv -LiteralPath $percorsoAnomalie -NoTypeInformation -Encoding utf8
}
else {
    'Gravita,Categoria,Oggetto,Controllo,Evidenza,Raccomandazione' |
        Set-Content -LiteralPath $percorsoAnomalie -Encoding utf8
}

$riepilogo = [ordered]@{
    Progetto   = 'VMware Infrastructure Audit Toolkit'
    GeneratoIl = $dataEsecuzione.ToString('o')
    Modalita   = 'Offline'

    Inventario = [ordered]@{
        MacchineVirtuali = $macchineVirtuali.Count
        Snapshot         = $snapshot.Count
        Datastore        = $datastore.Count
    }

    Anomalie = [ordered]@{
        Totale      = $risultati.Count
        Critiche    = @($risultati | Where-Object Gravita -eq 'Critico').Count
        Alte        = @($risultati | Where-Object Gravita -eq 'Alto').Count
        Medie       = @($risultati | Where-Object Gravita -eq 'Medio').Count
        Basse       = @($risultati | Where-Object Gravita -eq 'Basso').Count
        Informative = @($risultati | Where-Object Gravita -eq 'Informativo').Count
    }
}

$riepilogo |
    ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $percorsoRiepilogo -Encoding utf8

Write-Host ''
Write-Host 'Audit VMware completato correttamente.' -ForegroundColor Green
Write-Host "Macchine virtuali: $($macchineVirtuali.Count)"
Write-Host "Snapshot:           $($snapshot.Count)"
Write-Host "Datastore:          $($datastore.Count)"
Write-Host "Anomalie:           $($risultati.Count)"
Write-Host "Directory report:   $directoryEsecuzione"
