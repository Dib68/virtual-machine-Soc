# ============================================================================
#  bootstrap.ps1  -  Installer automatico della CyberSec AI VM (Windows)
#  Installa VirtualBox + Vagrant (se mancanti) e costruisce/avvia la VM.
# ============================================================================
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

function Banner($t){ Write-Host ""; Write-Host "==============================================" -ForegroundColor Cyan; Write-Host " $t" -ForegroundColor Cyan; Write-Host "==============================================" -ForegroundColor Cyan }
function Step($t){ Write-Host "==> $t" -ForegroundColor Yellow }
function Ok($t){ Write-Host "    [OK] $t" -ForegroundColor Green }
function Test-Cmd($n){ $null -ne (Get-Command $n -ErrorAction SilentlyContinue) }
function Refresh-Path {
  $m=[System.Environment]::GetEnvironmentVariable("Path","Machine")
  $u=[System.Environment]::GetEnvironmentVariable("Path","User")
  $env:Path="$m;$u"
  foreach($p in @("$env:ProgramFiles\Oracle\VirtualBox","$env:ProgramFiles\HashiCorp\Vagrant\bin","$env:ProgramW6432\HashiCorp\Vagrant\bin")){
    if((Test-Path $p) -and ($env:Path -notlike "*$p*")){ $env:Path="$env:Path;$p" }
  }
}

Banner "CyberSec AI VM - Installazione automatica"
Write-Host "Questo programma installera' tutto il necessario e creera' la VM."
Write-Host "Puoi lasciarlo lavorare: il download richiede tempo (alcuni GB)."
Write-Host ""

# --- winget disponibile? ---
Refresh-Path
if(-not (Test-Cmd winget)){
  Write-Host "ERRORE: 'winget' non e' disponibile su questo sistema." -ForegroundColor Red
  Write-Host "Apri il Microsoft Store, installa/aggiorna 'App Installer', poi riprova." -ForegroundColor Red
  Write-Host "In alternativa installa manualmente VirtualBox e Vagrant (vedi README)."
  Read-Host "Premi Invio per uscire"; exit 1
}

# --- VirtualBox ---
Step "Controllo VirtualBox..."
Refresh-Path
if(-not (Test-Cmd VBoxManage)){
  Step "Installo VirtualBox (potrebbe comparire una richiesta UAC / rete)..."
  winget install -e --id Oracle.VirtualBox --accept-source-agreements --accept-package-agreements
  Refresh-Path
} 
if(Test-Cmd VBoxManage){ Ok "VirtualBox pronto" } else { Write-Host "    Attenzione: VBoxManage non trovato nel PATH (riavvia il PC se necessario)." -ForegroundColor Red }

# --- Vagrant ---
Step "Controllo Vagrant..."
Refresh-Path
if(-not (Test-Cmd vagrant)){
  Step "Installo Vagrant..."
  winget install -e --id Hashicorp.Vagrant --accept-source-agreements --accept-package-agreements
  Refresh-Path
}
if(Test-Cmd vagrant){ Ok "Vagrant pronto" } else {
  Write-Host "Vagrant non risulta nel PATH. Chiudi e riapri INSTALLA, oppure riavvia il PC." -ForegroundColor Red
  Read-Host "Premi Invio per uscire"; exit 1
}

# --- plugin disksize (best effort) ---
Step "Configuro il plugin del disco (opzionale)..."
try {
  $plugins = vagrant plugin list 2>$null
  if(-not ($plugins -match "vagrant-disksize")){ vagrant plugin install vagrant-disksize } 
  Ok "Plugin pronto"
} catch { Write-Host "    (plugin saltato, non e' bloccante)" }

# --- Creazione/avvio VM ---
Banner "Creazione della VM (vagrant up)"
Write-Host "Da qui in poi scarica Kali Linux e installa tutti i tool, l'AI e il menu."
Write-Host "Puo' durare a lungo. Al termine si aprira' la finestra della VM."
Write-Host ""
vagrant up

Banner "FATTO!"

# --- Crea collegamenti sul Desktop (come una vera app) ---
try {
  $desktop = [Environment]::GetFolderPath("Desktop")
  $ws = New-Object -ComObject WScript.Shell
  function New-Shortcut($name,$target,$iconIdx){
    $lnk = $ws.CreateShortcut((Join-Path $desktop $name))
    $lnk.TargetPath = $target
    $lnk.WorkingDirectory = $ProjectRoot
    $lnk.IconLocation = "$env:SystemRoot\System32\shell32.dll,$iconIdx"
    $lnk.Save()
  }
  New-Shortcut "CyberSec AI VM - AVVIA.lnk"  (Join-Path $ProjectRoot "AVVIA.bat")  220
  New-Shortcut "CyberSec AI VM - SPEGNI.lnk" (Join-Path $ProjectRoot "SPEGNI.bat") 109
  Ok "Collegamenti creati sul Desktop"
} catch { Write-Host "    (collegamenti sul desktop saltati)" }
Write-Host "La CyberSec AI VM e' pronta." -ForegroundColor Green
Write-Host "Login nella VM:  vagrant / vagrant"
Write-Host "Dentro la VM digita 'cybermenu' per il menu con tutti i tool e i tutorial."
Write-Host ""
Write-Host "La prossima volta: usa 'AVVIA' per accendere la VM e 'SPEGNI' per spegnerla."
Read-Host "Premi Invio per chiudere"
