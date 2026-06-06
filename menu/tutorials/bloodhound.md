# BloodHound - analisi dei percorsi di attacco in Active Directory
## Cos'e'
Usa la teoria dei grafi per trovare percorsi che portano a Domain Admin.
## Flusso
1. Raccogli i dati con un "collector" (es. SharpHound/bloodhound-python).
   ```
   bloodhound-python -u user -p pass -d dominio.local -c all -ns 10.0.0.5
   ```
2. Avvia Neo4j e BloodHound:
   ```
   sudo neo4j start
   bloodhound
   ```
3. Importa i file .json e usa le query predefinite (es. "Shortest Path to
   Domain Admins").
