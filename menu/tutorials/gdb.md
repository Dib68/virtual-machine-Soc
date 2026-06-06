# GDB - GNU Debugger

## Uso base
```
gdb ./programma
break main        # breakpoint
run               # avvia
info registers    # registri
x/20x $rsp        # esamina lo stack
continue / step / next
```
Consigliato il plugin "pwndbg" o "gef" (spesso preinstallati in Kali)
per un'analisi piu' comoda durante l'exploitation.
