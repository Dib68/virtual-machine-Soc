# pwntools - libreria Python per exploit development / CTF
## Esempio base (exploit locale)
```python
from pwn import *
io = process('./vuln')          # o remote('host', porta)
payload = b'A'*40 + p64(0xdeadbeef)
io.sendline(payload)
io.interactive()
```
Strumento standard per le challenge di binary exploitation.
