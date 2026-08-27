# Changelog

## [Unreleased]

Prima versione in preparazione: `0.1.0`.

### Aggiunto

- Analisi offline di inventari VMware in formato CSV normalizzato.
- Controllo dell'età degli snapshot con soglie configurabili.
- Controllo dello spazio libero sui datastore.
- Controllo dello stato VMware Tools sulle VM accese.
- Esclusione delle VM spente o sospese dal controllo operativo dei Tools.
- Confronto della versione hardware virtuale con una soglia configurabile.
- Segnalazioni di qualità dei dati per i valori non validi gestiti.
- Classificazione e ordinamento delle anomalie per gravità.
- Generazione di report dettagliati CSV e riepiloghi JSON.
- Directory di output distinta per ogni esecuzione.
- Gestione degli inventari senza snapshot.
- Inventario dimostrativo con dati fittizi.
- 13 test automatici per snapshot e datastore.
- 23 test automatici per VMware Tools e hardware virtuale.
- Documentazione di utilizzo, architettura e limiti.
- Regole Git per escludere input privati e report generati.

### Limiti della prima versione

- Nessun collegamento diretto a vCenter o ESXi.
- Nessuna importazione diretta dei file Excel RVTools.
- Nessuna normalizzazione automatica degli export RVTools.
- Nessun report HTML.
- Validazione degli input limitata ai casi implementati.
