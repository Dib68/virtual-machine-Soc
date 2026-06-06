# YARA - regole per identificare malware
## Cos'e'
"Il pattern matching per malware": scrivi regole che cercano stringhe/byte
caratteristici nei file. Usato in DFIR e threat intel.
## Esempio di regola (salva come regola.yar)
```
rule Esempio_Sospetto {
  strings: $a = "cmd.exe /c" nocase
  condition: $a
}
```
## Uso
```
yara regola.yar /percorso/file        # su un file
yara -r regola.yar /percorso/cartella # ricorsivo
```
