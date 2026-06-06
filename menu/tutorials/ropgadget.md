# ROPgadget - ricerca di gadget per ROP chain
## Uso base
```
ROPgadget --binary ./programma
ROPgadget --binary ./programma --ropchain
ROPgadget --binary ./programma --only "pop|ret"
```
Trova le sequenze di istruzioni utili a costruire exploit ROP.
