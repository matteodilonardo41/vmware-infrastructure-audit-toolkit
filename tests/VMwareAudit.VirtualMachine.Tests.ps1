Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (
    Join-Path $PSScriptRoot '../modules/VMwareAudit.Core.psm1'
) -Force

$configurazione = [pscustomobject]@{
    VersioneHardwareMinima = 19
}

$testEseguiti = 0

function Assert-RisultatoVM {
    param(
        [string]$Nome,
        [AllowEmptyCollection()][object[]]$Risultati,
        [string]$Gravita,
        [string]$Categoria,
        [string]$Controllo
    )

    $numeroAtteso = if ([string]::IsNullOrEmpty($Gravita)) {
        0
    } else {
        1
    }

    if ($Risultati.Count -ne $numeroAtteso) {
        throw "FAIL [$Nome]: attesi $numeroAtteso risultati, ottenuti $($Risultati.Count)."
    }

    if ($numeroAtteso -eq 1) {
        $risultato = $Risultati[0]

        if (
            $risultato.Gravita -ne $Gravita -or
            $risultato.Categoria -ne $Categoria -or
            $risultato.Controllo -ne $Controllo -or
            $risultato.Oggetto -ne 'vm-test'
        ) {
            $dettaglio = $risultato | ConvertTo-Json -Compress
            throw "FAIL [$Nome]: risultato inatteso: $dettaglio"
        }
    }

    Write-Host "[OK] $Nome"
}

$casiTools = @'
Nome,Stato,Tools,Gravita,Categoria,Controllo
Tools correnti su VM accesa,PoweredOn,toolsOk,,,
Tools non correnti,PoweredOn,toolsOld,Medio,VMwareTools,VMwareToolsNonCorrenti
Tools fermi su VM accesa,PoweredOn,toolsNotRunning,Medio,VMwareTools,VMwareToolsNonInEsecuzione
Tools non rilevati,PoweredOn,toolsNotInstalled,Medio,VMwareTools,VMwareToolsNonRilevati
VM spenta: nessun falso allarme,PoweredOff,toolsNotRunning,,,
VM sospesa: nessun falso allarme,Suspended,toolsNotRunning,,,
Stato Tools sconosciuto,PoweredOn,sconosciuto,Medio,QualitaDati,StatoVMwareToolsNonValido
Stato Tools vuoto,PoweredOn,,Medio,QualitaDati,StatoVMwareToolsNonValido
Stato alimentazione sconosciuto,sconosciuto,toolsOk,Medio,QualitaDati,StatoAlimentazioneNonValido
Stato alimentazione vuoto,,toolsOk,Medio,QualitaDati,StatoAlimentazioneNonValido
'@ | ConvertFrom-Csv

foreach ($caso in $casiTools) {
    $vm = [pscustomobject]@{
        VM         = 'vm-test'
        PowerState = $caso.Stato
        ToolsStatus = $caso.Tools
    }

    $risultati = @(
        Get-VMwareToolsAuditFinding -MacchineVirtuali @($vm)
    )

    $parametri = @{
        Nome       = $caso.Nome
        Risultati  = $risultati
        Gravita    = $caso.Gravita
        Categoria  = $caso.Categoria
        Controllo  = $caso.Controllo
    }

    Assert-RisultatoVM @parametri
    $testEseguiti++
}

$casiHardware = @'
Nome,Versione,Gravita,Categoria,Controllo
Hardware sotto soglia,vmx-13,Basso,HardwareVirtuale,VersioneHardwareSottoSoglia
Hardware esattamente alla soglia,vmx-19,,,
Hardware sopra soglia,vmx-20,,,
Hardware senza prefisso,19,Medio,QualitaDati,VersioneHardwareNonValida
Hardware vuoto,,Medio,QualitaDati,VersioneHardwareNonValida
Hardware con versione zero,vmx-0,Medio,QualitaDati,VersioneHardwareNonValida
Hardware con numero fuori intervallo,vmx-99999999999999,Medio,QualitaDati,VersioneHardwareNonValida
'@ | ConvertFrom-Csv

foreach ($caso in $casiHardware) {
    $vm = [pscustomobject]@{
        VM              = 'vm-test'
        HardwareVersion = $caso.Versione
    }

    $parametriControllo = @{
        MacchineVirtuali = @($vm)
        Configurazione  = $configurazione
    }

    $risultati = @(
        Get-VirtualHardwareAuditFinding @parametriControllo
    )

    $parametri = @{
        Nome       = $caso.Nome
        Risultati  = $risultati
        Gravita    = $caso.Gravita
        Categoria  = $caso.Categoria
        Controllo  = $caso.Controllo
    }

    Assert-RisultatoVM @parametri
    $testEseguiti++
}

$risultati = @(
    Get-VMwareToolsAuditFinding -MacchineVirtuali @()
)

Assert-RisultatoVM -Nome 'Tools: raccolta VM vuota' -Risultati $risultati
$testEseguiti++

$risultati = @(
    Get-VirtualHardwareAuditFinding -MacchineVirtuali @() -Configurazione $configurazione
)

Assert-RisultatoVM -Nome 'Hardware: raccolta VM vuota' -Risultati $risultati
$testEseguiti++

foreach ($soglia in @('abc', '0', '-1', '19.5')) {
    $configurazioneErrata = [pscustomobject]@{
        VersioneHardwareMinima = $soglia
    }

    $rifiutata = $false

    try {
        Get-VirtualHardwareAuditFinding -MacchineVirtuali @() -Configurazione $configurazioneErrata |
            Out-Null
    }
    catch {
        if ($_.Exception.Message -ne 'VersioneHardwareMinima deve essere un numero intero positivo.') {
            throw
        }

        $rifiutata = $true
    }

    if (-not $rifiutata) {
        throw "FAIL: soglia hardware non valida accettata: $soglia"
    }

    Write-Host "[OK] Soglia hardware non valida rifiutata: $soglia"
    $testEseguiti++
}

Write-Host ''
Write-Host "Test VM completati: $testEseguiti superati."
