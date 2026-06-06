# Nuclei - scanner veloce basato su template
## Uso base
```
nuclei -u https://target           # scansione con tutti i template
nuclei -u https://target -t cves/  # solo CVE note
nuclei -l lista_url.txt            # molti target
nuclei -update-templates
```
Tra i tool offensivi/threat-hunting piu' usati oggi (ProjectDiscovery).
