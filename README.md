# VMware Infrastructure Audit Toolkit

[![VMware: Offline Audit](https://img.shields.io/badge/VMware-Offline%20Audit-0079B8?style=flat)](#stato-del-progetto)
[![PowerShell: 7.6.5 tested](https://img.shields.io/badge/PowerShell-7.6.5%20tested-5391FE?style=flat)](#requisiti)
[![Reports: CSV + JSON](https://img.shields.io/badge/Reports-CSV%20%2B%20JSON-00897B?style=flat)](#report)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellowgreen?style=flat)](LICENSE)
[![Local tests: 36 passed](https://img.shields.io/badge/Local%20tests-36%20passed-brightgreen?style=flat)](#test-automatici)

Toolkit PowerShell per analizzare offline inventari VMware e produrre segnalazioni verificabili su snapshot, spazio dei datastore, VMware Tools e hardware virtuale.

Non modifica l'infrastruttura: legge file CSV locali e genera report CSV e JSON.

## Stato del progetto

Versione iniziale: `0.1.0`.

La modalità attualmente implementata è esclusivamente offline.
Non sono necessari collegamenti a vCenter o ESXi, credenziali VMware o VMware PowerCLI.

## Funzionalità

- Controllo dell'età degli snapshot.
- Controllo della percentuale di spazio libero sui datastore.
- Controllo dello stato VMware Tools sulle VM accese.
- Confronto della versione hardware virtuale con una soglia configurabile.
- Segnalazione di alcuni valori non validi nei dati di origine.
- Ordinamento delle anomalie per gravità, categoria e oggetto.
- Report dettagliato CSV e riepilogo JSON.
- Dati dimostrativi fittizi.
- 36 casi di test automatici con esecuzione senza Pester.

## Requisiti

- PowerShell 7.
- Tre file CSV conformi allo schema del progetto.
- Permesso di lettura sugli input e di scrittura sulla directory dei report.

Ambiente verificato durante lo sviluppo: PowerShell 7.6.5 su Ubuntu in WSL.
L'esecuzione su altri ambienti non è ancora stata verificata.

## Avvio rapido

Eseguire dalla directory principale del progetto:

```bash
pwsh -NoProfile -File scripts/Invoke-VMwareAudit.ps1
```

Senza parametri, lo script utilizza:

- input: `sample-data/`;
- configurazione: `config/audit-config.example.json`;
- output: `reports/`.

Per utilizzare un inventario locale:

```bash
pwsh -NoProfile -File scripts/Invoke-VMwareAudit.ps1 -InputPath ./input -ConfigPath ./config/audit-config.example.json -OutputPath ./reports
```

La directory `input/` è esclusa da Git tramite `.gitignore`.

## Formato degli input

Tutti e tre i file sono obbligatori.

| File | Colonne utilizzate dai controlli |
| --- | --- |
| `vInfo.csv` | `VM`, `PowerState`, `ToolsStatus`, `HardwareVersion` |
| `vSnapshot.csv` | `VM`, `Snapshot`, `Created`, `SizeGB` |
| `vDatastore.csv` | `Datastore`, `CapacityGB`, `FreeGB` |

Usare i file in `sample-data/` come riferimento per lo schema.

Convenzioni:

- CSV separati da virgole.
- Valori decimali con il punto.
- Data di creazione snapshot nel formato `yyyy-MM-dd`.
- Versione hardware nel formato `vmx-N`, per esempio `vmx-19`.
- Stato VM: `PoweredOn`, `PoweredOff` oppure `Suspended`.
- Stato Tools: `toolsOk`, `toolsOld`, `toolsNotRunning` oppure `toolsNotInstalled`.

Se non sono presenti snapshot, mantenere `vSnapshot.csv` con la sola intestazione.

Le colonne aggiuntive presenti nei dati dimostrativi, come vCPU, memoria, host e cluster, non sono attualmente utilizzate per controlli di dimensionamento.

### Compatibilità RVTools

Non è implementata l'importazione diretta dei file Excel RVTools.

Anche un'esportazione CSV può richiedere la normalizzazione di intestazioni, stati, date e unità di misura prima di essere utilizzata.

Il formato richiesto è quello dei CSV del progetto, non quello nativo di qualsiasi versione di RVTools.

## Configurazione

Le soglie sono definite in `config/audit-config.example.json`.

| Parametro | Valore dimostrativo | Regola |
| --- | --- | --- |
| `GiorniAvvisoSnapshot` | 7 | Gravità Alto da questa età |
| `GiorniCriticiSnapshot` | 30 | Gravità Critico da questa età |
| `PercentualeLiberaAvvisoDatastore` | 20 | Gravità Alto a questa percentuale o inferiore |
| `PercentualeLiberaCriticaDatastore` | 10 | Gravità Critico a questa percentuale o inferiore |
| `VersioneHardwareMinima` | 19 | Gravità Basso per versioni inferiori |

Quando è raggiunta la soglia critica, questa prevale su quella di avviso.

L'età degli snapshot è calcolata in giorni rispetto alla data locale di esecuzione. Il numero di segnalazioni può quindi cambiare nel tempo anche usando gli stessi CSV.

La percentuale libera dei datastore viene arrotondata a due decimali prima del confronto.

La soglia hardware è una policy configurabile: non rappresenta un requisito universale VMware né un'indicazione automatica di incompatibilità.

## Interpretazione dei controlli VMware Tools

Sulle VM accese:

- `toolsOk`: nessuna segnalazione;
- `toolsOld`: segnalazione Medio per versione non corrente;
- `toolsNotRunning`: segnalazione Medio per Tools non in esecuzione;
- `toolsNotInstalled`: segnalazione Medio per Tools non rilevati;
- stato vuoto o sconosciuto: segnalazione di qualità dei dati.

Il controllo operativo dei Tools viene saltato sulle VM spente o sospese.

Una versione non corrente non dimostra, da sola, la presenza di una vulnerabilità. Lo stato dei Tools deve essere verificato nel contesto del sistema guest.

## Report

Ogni esecuzione crea una directory:

```text
reports/yyyyMMdd-HHmmss-fff/
```

Contenuto:

- `findings.csv`: gravità, categoria, oggetto, controllo, evidenza e raccomandazione;
- `summary.json`: data di esecuzione, conteggi dell'inventario e riepilogo per gravità.

I report generati sono esclusi da Git.
La directory `reports/example/` costituisce un'eccezione destinata esclusivamente a esempi pubblici con dati fittizi.

## Test automatici

Eseguire entrambi i comandi dalla directory principale:

```bash
pwsh -NoProfile -File tests/VMwareAudit.Tests.ps1
pwsh -NoProfile -File tests/VMwareAudit.VirtualMachine.Tests.ps1
```

| Suite | Casi |
| --- | --- |
| Snapshot e datastore | 13 |
| VMware Tools e hardware virtuale | 23 |
| Totale | 36 |

I test utilizzano dati sintetici e, per gli snapshot, una data di riferimento fissa.
Non si collegano a VMware e non generano report di audit.

Ogni suite si interrompe al primo errore.

## Sicurezza e limiti

Il toolkit non elimina snapshot, non modifica VM o datastore e non esegue aggiornamenti.

Non raccoglie credenziali e non invia gli inventari a servizi esterni.

I risultati descrivono i dati forniti, non lo stato in tempo reale dell'infrastruttura. Accuratezza e aggiornamento dell'inventario restano responsabilità di chi lo prepara.

La validazione dei dati copre solo i casi implementati: non è una verifica completa dello schema CSV o di ogni possibile incoerenza.

Non sono implementati controlli di vulnerabilità, fine supporto dei sistemi operativi, integrità dei backup o compatibilità completa per una migrazione.

Prima di intervenire sull'infrastruttura, verificare ogni segnalazione, la compatibilità e le procedure di backup e ripristino.

Prima di un commit, controllare sempre i file inclusi: `.gitignore` non sostituisce una verifica dei dati sensibili.

## Sviluppi futuri

Funzionalità non ancora implementate:

- raccolta diretta in sola lettura tramite VMware PowerCLI;
- importazione e normalizzazione degli export RVTools;
- report HTML;
- ulteriori controlli di qualità e coerenza degli input.
