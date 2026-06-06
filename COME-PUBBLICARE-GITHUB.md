# Come pubblicare il progetto su GitHub (repo PUBBLICA)

Tutti i file sono pronti nella cartella del progetto (con LICENSE, .gitignore,
README e i testi). Ti basta caricarli su GitHub. Scegli UNA delle due strade.
La Strada A NON richiede di installare nulla.

---

## STRADA A — Senza installare nulla (dal sito, la piu' semplice)

1. Vai su https://github.com/new (accedi col tuo account).
2. Repository name: `cybersec-ai-vm`
3. Description: `VM Kali all-in-one con AI integrata, GUI moderna e tool red/blue team`
4. Seleziona **Public**.
5. NON spuntare "Add a README" (ce l'abbiamo gia'). Clicca **Create repository**.
6. Nella pagina che appare, clicca su **"uploading an existing file"**.
7. Trascina TUTTI i file e le cartelle della cartella del progetto
   `C:\Users\...\virtual machine Soc` nella finestra del browser.
8. In basso scrivi un messaggio (es. "primo commit") e clicca **Commit changes**.

Fatto: la repo e' pubblica. Il link sara':
`https://github.com/TUO-UTENTE/cybersec-ai-vm`

---

## STRADA B — Da terminale (piu' veloce se hai Git)

1. Installa Git per Windows: https://git-scm.com/download/win (se non ce l'hai).
2. Installa GitHub CLI: https://cli.github.com/  (facoltativo ma comodo).
3. Apri il "Prompt dei comandi" nella cartella del progetto e incolla:

   Con GitHub CLI (fa login e crea la repo da solo):
   ```
   gh auth login
   gh repo create cybersec-ai-vm --public --source . --remote origin --push
   ```

   Oppure, se hai gia' creato la repo vuota sul sito (Strada A punti 1-5):
   ```
   git remote add origin https://github.com/TUO-UTENTE/cybersec-ai-vm.git
   git branch -M main
   git push -u origin main
   ```

---

## Dopo la pubblicazione
- Copia il link della repo e incollalo nel post LinkedIn (vedi LINKEDIN-POST.md),
  sostituendo `TUO-UTENTE`.
- Su GitHub, nella pagina del repo, clicca l'ingranaggio accanto a "About" e
  aggiungi i "Topics": `cybersecurity`, `kali-linux`, `soc`, `pentesting`,
  `blue-team`, `vagrant`, `homelab`. Aiuta a farti trovare.

## Nota
La repo NON include file pesanti (immagini .ova, box, la VM stessa): sono esclusi
apposta tramite `.gitignore`. Chi scarica il repo ricostruisce la VM con un clic
su `INSTALLA.bat`. Questo e' il modo corretto e standard di distribuire il progetto.
