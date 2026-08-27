Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (
    Join-Path $PSScriptRoot '../modules/VMwareAudit.Core.psm1'
) -Force

$configurazione = [pscustomobject]@{
    GiorniAvvisoSnapshot                = 7
    GiorniCriticiSnapshot               = 30
    PercentualeLiberaAvvisoDatastore    = 20
    PercentualeLiberaCriticaDatastore   = 10
}

$dataRiferimento = [datetime]::new(2026, 8, 26)
$testEseguiti = 0

function Assert-Risultato {
    param(
        [string]$Nome,
        [AllowEmptyCollection()][object[]]$Risultati,
        [string]$Gravita,
        [string]$Controllo
    )

    $numeroAtteso = if ($Gravita -eq '') { 0 } else { 1 }

    if ($Risultati.Count -ne $numeroAtteso) {
        throw "FAIL [$Nome]: attesi $numeroAtteso risultati, ottenuti $($Risultati.Count)."
    }

    if ($numeroAtteso -eq 1) {
        if ($Risultati[0].Gravita -ne $Gravita) {
            throw "FAIL [$Nome]: gravita attesa $Gravita, ottenuta $($Risultati[0].Gravita)."
        }

        if ($Risultati[0].Controllo -ne $Controllo) {
            throw "FAIL [$Nome]: controllo atteso $Controllo, ottenuto $($Risultati[0].Controllo)."
        }
    }

    Write-Host "[OK] $Nome"
}

$testSnapshot = @(
    @{ Nome = 'Snapshot recente: nessuna anomalia'; Data = '2026-08-20'; Gravita = '' }
    @{ Nome = 'Snapshot: soglia avviso a 7 giorni'; Data = '2026-08-19'; Gravita = 'Alto' }
    @{ Nome = 'Snapshot: 29 giorni ancora avviso'; Data = '2026-07-28'; Gravita = 'Alto' }
    @{ Nome = 'Snapshot: soglia critica a 30 giorni'; Data = '2026-07-27'; Gravita = 'Critico' }
    @{ Nome = 'Snapshot: data non valida'; Data = 'data-errata'; Gravita = 'Critico' }
)

foreach ($caso in $testSnapshot) {
    $snapshot = [pscustomobject]@{
        VM       = 'vm-test'
        Snapshot = 'snapshot-test'
        Created  = $caso.Data
        SizeGB   = '5'
    }

    $parametri = @{
        Snapshot        = @($snapshot)
        Configurazione  = $configurazione
        DataRiferimento = $dataRiferimento
    }

    $risultati = @(Get-SnapshotAuditFinding @parametri)

    $controllo = if ($caso.Data -eq 'data-errata') {
        'DataSnapshotNonValida'
    } else {
        'EtaSnapshot'
    }

    Assert-Risultato -Nome $caso.Nome -Risultati $risultati -Gravita $caso.Gravita -Controllo $controllo
    $testEseguiti++
}

$testDatastore = @(
    @{ Nome = 'Datastore: spazio sufficiente'; Capacita = '100'; Libero = '21'; Gravita = ''; NonValido = $false }
    @{ Nome = 'Datastore: soglia avviso al 20%'; Capacita = '100'; Libero = '20'; Gravita = 'Alto'; NonValido = $false }
    @{ Nome = 'Datastore: 11% ancora avviso'; Capacita = '100'; Libero = '11'; Gravita = 'Alto'; NonValido = $false }
    @{ Nome = 'Datastore: soglia critica al 10%'; Capacita = '100'; Libero = '10'; Gravita = 'Critico'; NonValido = $false }
    @{ Nome = 'Datastore: capacita zero'; Capacita = '0'; Libero = '0'; Gravita = 'Critico'; NonValido = $true }
    @{ Nome = 'Datastore: capacita negativa'; Capacita = '-100'; Libero = '0'; Gravita = 'Critico'; NonValido = $true }
    @{ Nome = 'Datastore: spazio libero negativo'; Capacita = '100'; Libero = '-1'; Gravita = 'Critico'; NonValido = $true }
    @{ Nome = 'Datastore: capacita non numerica'; Capacita = 'abc'; Libero = '10'; Gravita = 'Critico'; NonValido = $true }
)

foreach ($caso in $testDatastore) {
    $datastore = [pscustomobject]@{
        Datastore  = 'datastore-test'
        CapacityGB = $caso.Capacita
        FreeGB     = $caso.Libero
    }

    $parametri = @{
        Datastore      = @($datastore)
        Configurazione = $configurazione
    }

    $risultati = @(Get-DatastoreAuditFinding @parametri)

    $controllo = if ($caso.NonValido) {
        'CapacitaDatastoreNonValida'
    } else {
        'SpazioLiberoDatastore'
    }

    Assert-Risultato -Nome $caso.Nome -Risultati $risultati -Gravita $caso.Gravita -Controllo $controllo
    $testEseguiti++
}

Write-Host ""
Write-Host "Test completati: $testEseguiti superati."
