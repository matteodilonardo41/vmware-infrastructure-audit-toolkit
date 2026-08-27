Set-StrictMode -Version Latest

function New-AuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Critico', 'Alto', 'Medio', 'Basso', 'Informativo')]
        [string]$Gravita,

        [Parameter(Mandatory)]
        [string]$Categoria,

        [Parameter(Mandatory)]
        [string]$Oggetto,

        [Parameter(Mandatory)]
        [string]$Controllo,

        [Parameter(Mandatory)]
        [string]$Evidenza,

        [Parameter(Mandatory)]
        [string]$Raccomandazione
    )

    return [pscustomobject][ordered]@{
        Gravita         = $Gravita
        Categoria       = $Categoria
        Oggetto         = $Oggetto
        Controllo       = $Controllo
        Evidenza        = $Evidenza
        Raccomandazione = $Raccomandazione
    }
}

function Get-SnapshotAuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Snapshot,

        [Parameter(Mandatory)]
        [pscustomobject]$Configurazione,

        [datetime]$DataRiferimento = (Get-Date)
    )

    foreach ($elemento in $Snapshot) {
        try {
            $dataCreazione = [datetime]::ParseExact(
                $elemento.Created,
                'yyyy-MM-dd',
                [Globalization.CultureInfo]::InvariantCulture
            )
        }
        catch {
            $parametri = @{
                Gravita         = 'Critico'
                Categoria       = 'QualitaDati'
                Oggetto         = $elemento.VM
                Controllo       = 'DataSnapshotNonValida'
                Evidenza        = "Data non valida: $($elemento.Created)"
                Raccomandazione = "Correggere l'inventario di origine prima di proseguire."
            }

            New-AuditFinding @parametri
            continue
        }

        $giorni = [math]::Floor(
            ($DataRiferimento.Date - $dataCreazione.Date).TotalDays
        )

        if ($giorni -ge [int]$Configurazione.GiorniCriticiSnapshot) {
            $gravita = 'Critico'
        }
        elseif ($giorni -ge [int]$Configurazione.GiorniAvvisoSnapshot) {
            $gravita = 'Alto'
        }
        else {
            continue
        }

        $parametri = @{
            Gravita         = $gravita
            Categoria       = 'Snapshot'
            Oggetto         = $elemento.VM
            Controllo       = 'EtaSnapshot'
            Evidenza        = "$giorni giorni; $($elemento.SizeGB) GB; snapshot $($elemento.Snapshot)"
            Raccomandazione = "Verificare la snapshot e pianificarne il consolidamento o la rimozione."
        }

        New-AuditFinding @parametri
    }
}

function Get-DatastoreAuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$Datastore,

        [Parameter(Mandatory)]
        [pscustomobject]$Configurazione
    )

    foreach ($elemento in $Datastore) {
        try {
            $capacitaGB = [double]::Parse(
                $elemento.CapacityGB,
                [Globalization.CultureInfo]::InvariantCulture
            )

            $spazioLiberoGB = [double]::Parse(
                $elemento.FreeGB,
                [Globalization.CultureInfo]::InvariantCulture
            )

            if ($capacitaGB -le 0 -or $spazioLiberoGB -lt 0) {
                throw "Valori di capacità non validi."
            }
        }
        catch {
            $parametri = @{
                Gravita         = 'Critico'
                Categoria       = 'QualitaDati'
                Oggetto         = $elemento.Datastore
                Controllo       = 'CapacitaDatastoreNonValida'
                Evidenza        = "Il valore della capacità o dello spazio libero non è valido."
                Raccomandazione = "Correggere l'inventario di origine prima di proseguire."
            }

            New-AuditFinding @parametri
            continue
        }

        $percentualeLibera = [math]::Round(
            ($spazioLiberoGB / $capacitaGB) * 100,
            2
        )

        if ($percentualeLibera -le [double]$Configurazione.PercentualeLiberaCriticaDatastore) {
            $gravita = 'Critico'
        }
        elseif ($percentualeLibera -le [double]$Configurazione.PercentualeLiberaAvvisoDatastore) {
            $gravita = 'Alto'
        }
        else {
            continue
        }

        $parametri = @{
            Gravita         = $gravita
            Categoria       = 'Datastore'
            Oggetto         = $elemento.Datastore
            Controllo       = 'SpazioLiberoDatastore'
            Evidenza        = "$percentualeLibera% libero; $spazioLiberoGB GB su $capacitaGB GB"
            Raccomandazione = "Verificare la capacità del datastore e pianificare un intervento."
        }

        New-AuditFinding @parametri
    }
}

function Get-VMwareToolsAuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MacchineVirtuali
    )

    foreach ($elemento in $MacchineVirtuali) {
        $statoVM = ([string]$elemento.PowerState).Trim()
        $statoTools = ([string]$elemento.ToolsStatus).Trim()

        # Non valutare lo stato operativo dei Tools su VM spente o sospese.
        if ($statoVM -in @('PoweredOff', 'Suspended')) {
            continue
        }

        if ($statoVM -eq 'PoweredOn' -and $statoTools -eq 'toolsOk') {
            continue
        }

        $parametri = @{
            Gravita         = 'Medio'
            Categoria       = 'QualitaDati'
            Oggetto         = $elemento.VM
            Controllo       = 'StatoAlimentazioneNonValido'
            Evidenza        = "Stato VM: $statoVM; stato Tools: $statoTools"
            Raccomandazione = "Verificare il valore PowerState nel CSV di origine."
        }

        if ($statoVM -eq 'PoweredOn') {
            $parametri.Categoria = 'VMwareTools'

            switch ($statoTools) {
                'toolsOld' {
                    $parametri.Controllo = 'VMwareToolsNonCorrenti'
                    $parametri.Raccomandazione = "Verificare versione e compatibilita dei Tools e valutare un aggiornamento supportato."
                }

                'toolsNotRunning' {
                    $parametri.Controllo = 'VMwareToolsNonInEsecuzione'
                    $parametri.Raccomandazione = "Verificare nel guest il servizio VMware Tools o open-vm-tools e se la VM ha completato avvio o riavvio."
                }

                'toolsNotInstalled' {
                    $parametri.Controllo = 'VMwareToolsNonRilevati'
                    $parametri.Raccomandazione = "Verificare se VMware Tools o open-vm-tools sono installati, sono mai stati eseguiti e sono previsti per questo guest."
                }

                default {
                    $parametri.Categoria = 'QualitaDati'
                    $parametri.Controllo = 'StatoVMwareToolsNonValido'
                    $parametri.Raccomandazione = "Verificare il valore ToolsStatus nel CSV: stato assente o non riconosciuto."
                }
            }
        }

        New-AuditFinding @parametri
    }
}

function Get-VirtualHardwareAuditFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$MacchineVirtuali,

        [Parameter(Mandatory)]
        [pscustomobject]$Configurazione
    )

    $versioneMinima = 0

    $sogliaValida = [int]::TryParse(
        [string]$Configurazione.VersioneHardwareMinima,
        [ref]$versioneMinima
    )

    if (-not $sogliaValida -or $versioneMinima -le 0) {
        throw "VersioneHardwareMinima deve essere un numero intero positivo."
    }

    foreach ($elemento in $MacchineVirtuali) {
        $hardware = ([string]$elemento.HardwareVersion).Trim()
        $versione = 0

        $corrispondenza = [regex]::Match(
            $hardware,
            '^vmx-([1-9][0-9]*)$'
        )

        $versioneValida = $false

        if ($corrispondenza.Success) {
            $versioneValida = [int]::TryParse(
                $corrispondenza.Groups[1].Value,
                [ref]$versione
            )
        }

        if (-not $versioneValida) {
            $parametri = @{
                Gravita         = 'Medio'
                Categoria       = 'QualitaDati'
                Oggetto         = $elemento.VM
                Controllo       = 'VersioneHardwareNonValida'
                Evidenza        = "HardwareVersion: $hardware"
                Raccomandazione = "Verificare HardwareVersion nel CSV: il formato previsto e vmx-N, per esempio vmx-19."
            }

            New-AuditFinding @parametri
            continue
        }

        if ($versione -ge $versioneMinima) {
            continue
        }

        $parametri = @{
            Gravita         = 'Basso'
            Categoria       = 'HardwareVirtuale'
            Oggetto         = $elemento.VM
            Controllo       = 'VersioneHardwareSottoSoglia'
            Evidenza        = "Versione: $hardware; soglia configurata: vmx-$versioneMinima"
            Raccomandazione = "Valutare la policy e la compatibilita con host ESXi, sistema guest e backup prima di pianificare un eventuale aggiornamento."
        }

        New-AuditFinding @parametri
    }
}

Export-ModuleMember -Function @(
    'New-AuditFinding'
    'Get-SnapshotAuditFinding'
    'Get-DatastoreAuditFinding'
    'Get-VMwareToolsAuditFinding'
    'Get-VirtualHardwareAuditFinding'
)
