# Project 02 — Debugging con GDB + ST-LINK

Obiettivo: seguire il firmware del Project 01 dal reset alla scrittura che
accende il LED verde. Il codice applicativo resta invariato.

## 1. I tre elementi

```text
arm-none-eabi-gdb → OpenOCD → ST-LINK / SWD → Cortex-M4
```

GDB legge simboli, sorgenti e informazioni di debug da `firmware.elf`.
OpenOCD gestisce la connessione alla scheda. Il file `.bin` non contiene
le informazioni necessarie per il debug del sorgente.

La configurazione `openocd.cfg` seleziona il Cortex-M4. Disabilita inoltre
l'evento `reset-init` standard del target STM32WL che modifica il clock MSI:
in questo laboratorio vogliamo studiare la configurazione dopo reset.

## 2. Collegamento

Collega la scheda alla porta USB dello ST-LINK con un cavo dati.
Chiudi eventuali connessioni attive di STM32CubeProgrammer alla scheda.
Apri due terminali nella radice del repository.

Nel primo:

```sh
make
openocd -f openocd.cfg
```

Attendi il riconoscimento del target e il messaggio di ascolto GDB sulla
porta 3333. Lascia questo terminale aperto.

Nel secondo:

```sh
arm-none-eabi-gdb firmware.elf
```

Da questo momento i comandi seguenti vanno nel prompt `(gdb)`:

```gdb
set pagination off
target extended-remote localhost:3333
monitor reset halt
load
monitor reset halt
maintenance flush register-cache
```

`load` programma la Flash con l'ELF appena compilato. Il secondo reset
ristabilisce lo stato iniziale dopo la programmazione. Un LED già acceso
prima della connessione non descrive lo stato del nuovo esperimento.
`maintenance flush register-cache` forza GDB a rileggere i registri:
dopo un reset tramite `monitor`, può mostrare valori conservati in cache.
Ripeti questo comando dopo ogni `monitor reset halt` prima di leggere PC/SP.

## 3. Reset_Handler: PC, stack e vector table

```gdb
x/2wx 0x08000000
info registers
p/x $pc
p/x $sp
x/i $pc
disassemble /r Reset_Handler
```

Nella build iniziale del progetto, la vector table contiene:

```text
0x08000000: 0x20010000  0x08000009
```

La prima word è il valore iniziale di MSP: la cima dello stack.
La seconda è il reset vector: il bit 0 indica lo stato Thumb;
l'indirizzo dell'istruzione di `Reset_Handler` è `0x08000008`.
Verifica questi valori nell'ELF corrente invece di assumere che gli
indirizzi del codice restino uguali dopo ogni modifica.

`PC` indica il punto di esecuzione. `SP` è lo stack pointer attivo;
in questa applicazione dopo reset è MSP. `LR` contiene il collegamento
di ritorno dalle chiamate. `r0`–`r12` sono registri generali; `xPSR`
contiene stato, flag e numero dell'eccezione corrente. Non aspettarti
valori applicativi significativi per tutti i registri subito dopo reset.

Per sperimentare i breakpoint:

```gdb
hbreak Reset_Handler
hbreak *main
info breakpoints
monitor reset halt
```

Il reset con halt può averti già fermato su `Reset_Handler`, senza un
messaggio di breakpoint. Controlla `PC`. Se punta alla sua prima istruzione:

```gdb
stepi
```

L'istruzione `bl main` entra in `main` e aggiorna `LR`. Il breakpoint
`*main` indica l'ingresso esatto della funzione, prima del prologo;
`break main` può invece fermarsi sulla prima riga C dopo il prologo.

```gdb
info registers pc sp lr r7
disassemble /r main
```

Nella build iniziale il prologo contiene `push {r7}`: eseguendolo con
`stepi`, SP passa da `0x20010000` a `0x2000fffc`.

## 4. Dal C alle scritture hardware

```gdb
display/i $pc
```

Usa `stepi` per eseguire una singola istruzione macchina. `step` segue
invece le righe sorgente: una riga C può comprendere diverse istruzioni.
`nexti` supera una chiamata senza seguirne l'interno; qui usa `stepi`
per osservare anche `bl main`.

Segui ogni sequenza `ldr` → modifica del valore → `str`:

- `ldr` può caricare un indirizzo dalla literal pool oppure leggere il
  contenuto di memoria: guarda gli operandi per distinguerli.
- `orr` imposta bit, `bic` li azzera.
- `str` effettua la scrittura in memoria, quindi anche nei registri GPIO/RCC.

Prima dell'abilitazione del clock, leggi RCC:

```gdb
x/wx 0x5800004c
```

Esegui la `str` che abilita GPIOB, poi rileggi RCC. Il bit 1 deve essere 1:

```gdb
p/x (*(unsigned int *)0x5800004c & 0x2)
```

Esegui anche il read-back RCC prima di osservare i registri GPIO.
Le letture del GPIO con clock disabilitato non sono una base affidabile
per questo confronto.

Dopo le due scritture a MODER:

```gdb
x/wx 0x48000400
p/x ((*(unsigned int *)0x48000400 >> 18) & 3)
```

Il campo MODE9 deve valere `1` (`01` binario). Confronta il campo,
senza aspettarti che l'intero registro abbia un unico valore prefissato.

Prima della scrittura a ODR, controlla:

```gdb
x/wx 0x48000414
```

Esegui con `stepi` la `str` diretta a ODR. Ora:

```gdb
x/wx 0x48000414
p/x (*(unsigned int *)0x48000414 & 0x200)
```

Il risultato della maschera deve essere `0x200`: PB9 è alto e il LED
verde deve essere acceso. Fermare il processore non azzera l'uscita GPIO:
il LED resta acceso anche mentre sei fermo nel debugger.

## 5. Ripetere e terminare

```gdb
monitor reset halt
continue
```

Con i breakpoint ancora presenti, `continue` riprende fino al successivo
breakpoint. `Ctrl-C` interrompe un'esecuzione libera. Puoi disabilitare
un breakpoint con `disable NUMERO` oppure eliminarlo con `delete NUMERO`.

Per lasciare il firmware in esecuzione:

```gdb
delete
monitor reset run
detach
quit
```

Ferma poi OpenOCD con `Ctrl-C` nel primo terminale.

## Risultato del laboratorio

Annota i valori osservati di PC/SP al reset, SP dopo il prologo,
GPIOBEN dopo l'abilitazione, MODE9 dopo la configurazione e OD9 prima/dopo
la scrittura. Spiega quale istruzione cambia fisicamente il LED.

Se OpenOCD non riconosce ST-LINK, controlla cavo dati, porta USB e altre
applicazioni connesse al debugger. Se GDB non si collega, conserva l'output
di OpenOCD: deve essere ancora attivo e in ascolto su 3333.

Fonti: [GDB e OpenOCD](https://openocd.org/doc/html/GDB-and-OpenOCD.html),
[configurazione ufficiale STM32WL](https://github.com/openocd-org/openocd/blob/master/tcl/target/stm32wlx.cfg).
