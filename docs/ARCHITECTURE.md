# Architettura

## Obiettivo

Analizzare inventari VMware locali senza modificare l'infrastruttura e produrre segnalazioni con evidenze e raccomandazioni.

La versione corrente opera esclusivamente offline.

## Componenti

| Componente | Responsabilità |
| --- | --- |
| `scripts/Invoke-VMwareAudit.ps1` | Gestione dei percorsi, lettura degli input, esecuzione dei controlli e generazione dei report |
| `modules/VMwareAudit.Core.psm1` | Funzioni di analisi e costruzione delle segnalazioni |
| `config/audit-config.example.json` | Soglie dimostrative configurabili |
| `sample-data/` | Inventari fittizi conformi allo schema del progetto |
| `tests/VMwareAudit.Tests.ps1` | Test per snapshot e datastore |
| `tests/VMwareAudit.VirtualMachine.Tests.ps1` | Test per Tools e hardware virtuale |
| `reports/` | Output delle esecuzioni, escluso da Git salvo gli esempi pubblici |

## Flusso di esecuzione

1. Risoluzione dei percorsi di input, configurazione e output.
2. Importazione del modulo PowerShell.
3. Verifica della presenza dei tre CSV obbligatori e della configurazione.
4. Lettura della configurazione JSON e degli inventari CSV.
5. Esecuzione dei controlli sulle raccolte non vuote.
6. Ordinamento dei risultati per gravità, categoria e oggetto.
7. Creazione di una nuova directory di esecuzione.
8. Esportazione di `findings.csv` e `summary.json`.

Una directory di esecuzione già esistente non viene riutilizzata.

Non sono previste connessioni di rete, richieste di credenziali o operazioni sulle VM.

## Modulo di analisi

### New-AuditFinding

Costruisce un oggetto con uno schema comune:

- `Gravita`
- `Categoria`
- `Oggetto`
- `Controllo`
- `Evidenza`
- `Raccomandazione`

Le gravità ammesse sono Critico, Alto, Medio, Basso e Informativo.

### Get-SnapshotAuditFinding

Legge la data di creazione nel formato `yyyy-MM-dd` e calcola l'età in giorni rispetto alla data di riferimento.

La soglia critica prevale su quella di avviso.
Le date non interpretabili generano una segnalazione di qualità dei dati.

Nelle esecuzioni ordinarie la data di riferimento è quella corrente.
Nei test viene fornita una data fissa.

### Get-DatastoreAuditFinding

Interpreta capacità e spazio libero usando la cultura numerica invariant.

Calcola la percentuale libera, la arrotonda a due decimali e la confronta con le soglie configurate.

Capacità non positive, spazio libero negativo ed errori di conversione numerica generano una segnalazione di qualità dei dati.

Questi controlli non costituiscono una validazione completa di tutti i possibili valori numerici o delle relazioni tra i campi.

### Get-VMwareToolsAuditFinding

Valuta lo stato operativo dei Tools soltanto sulle VM accese.

Le VM spente o sospese vengono escluse dal controllo.
Gli stati non riconosciuti delle VM accese e gli stati di alimentazione non validi generano segnalazioni di qualità dei dati.

Il controllo utilizza i valori presenti nell'inventario, senza interrogare il sistema guest.

### Get-VirtualHardwareAuditFinding

Verifica che la soglia configurata sia un intero positivo.

Interpreta versioni nel formato `vmx-N` e segnala quelle inferiori alla soglia.

Il confronto è numerico: la soglia è una policy locale, non una verifica completa della compatibilità VMware.

## Gestione degli errori

Lo script principale utilizza `Set-StrictMode` e imposta gli errori come bloccanti.

File mancanti, JSON non interpretabile e altri errori non gestiti interrompono l'esecuzione.

I casi di dati non validi esplicitamente gestiti dalle funzioni producono invece segnalazioni nel report.

Non è implementata una validazione centralizzata e completa delle intestazioni CSV, delle righe e di tutte le relazioni tra le soglie.

## Output

`findings.csv` contiene le singole segnalazioni.

`summary.json` contiene:

- identificazione del progetto;
- data di esecuzione;
- modalità offline;
- conteggi di VM, snapshot e datastore;
- totale delle anomalie e conteggi per gravità.

Il report non include ancora una copia della configurazione o le impronte dei file di input.

Se non ci sono anomalie, il CSV viene creato con la sola intestazione.

## Test

Le due suite sono script PowerShell autonomi e non richiedono Pester.

Sono presenti 36 casi complessivi, con dati sintetici e risultati attesi espliciti.

La copertura comprende soglie, alcuni input non validi, esclusione dei Tools sulle VM spente o sospese e raccolte VM vuote.

I test delle funzioni non equivalgono a una copertura completa di ogni percorso dello script principale o di ogni possibile inventario reale.

## Confine tra dati pubblici e privati

- `sample-data/` contiene esclusivamente dati fittizi.
- `input/` e `private-data/` sono esclususe da Git.
- I report generati sono esclusi da Git.
- `reports/example/` è pubblicabile e deve contenere soltanto dati fittizi.

Le regole `.gitignore` riducono il rischio di pubblicazione accidentale, ma non sostituiscono il controllo dei file prima del commit.

## Funzionalità future

Raccolta PowerCLI, normalizzazione RVTools e report HTML non sono implementati nella versione corrente.
