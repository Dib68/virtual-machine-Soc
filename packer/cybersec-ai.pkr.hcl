# ============================================================================
#  cybersec-ai.pkr.hcl  -  Build avanzata dell'immagine .ova con Packer
#  Crea da zero una VM Kali, applica i nostri script di provisioning ed
#  esporta un .ova distribuibile.
#
#  Requisiti: Packer + VirtualBox.
#  Uso:
#     packer init .
#     packer build cybersec-ai.pkr.hcl
#
#  NOTA: aggiorna 'iso_url' e 'iso_checksum' all'ultima Kali installer ISO
#  (https://www.kali.org/get-kali/). Il file http/preseed.cfg automatizza
#  l'installazione. Questo metodo e' per utenti avanzati; per la via rapida
#  usa ./build-ova.sh (basato su Vagrant).
# ============================================================================

packer {
  required_plugins {
    virtualbox = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/virtualbox"
    }
  }
}

variable "iso_url" {
  type    = string
  default = "https://cdimage.kali.org/kali-2025.2/kali-linux-2025.2-installer-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  # Sostituisci con il checksum ufficiale (sha256) della ISO scelta.
  default = "file:https://cdimage.kali.org/kali-2025.2/SHA256SUMS"
}

source "virtualbox-iso" "cybersec" {
  guest_os_type        = "Debian_64"
  iso_url              = var.iso_url
  iso_checksum         = var.iso_checksum
  vm_name              = "CyberSec-AI-VM"
  cpus                 = 4
  memory               = 8192
  disk_size            = 61440            # 60 GB
  hard_drive_interface = "sata"
  gfx_controller       = "vmsvga"
  gfx_vram_size        = 128

  # Avvio installazione automatica tramite preseed
  http_directory = "http"
  boot_wait      = "5s"
  boot_command = [
    "<esc><wait>",
    "install <wait>",
    "preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg <wait>",
    "debian-installer=it_IT locale=it_IT.UTF-8 keymap=it <wait>",
    "hostname=cybersec-ai <wait>",
    "<enter><wait>"
  ]

  # Credenziali create dal preseed
  ssh_username = "vagrant"
  ssh_password = "vagrant"
  ssh_timeout  = "60m"

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"
  format           = "ova"
  output_directory = "output-ova"
}

build {
  sources = ["source.virtualbox-iso.cybersec"]

  # Carica gli script e i file del progetto nella VM
  provisioner "shell" {
    inline = ["sudo mkdir -p /vagrant && sudo chown vagrant:vagrant /vagrant"]
  }
  provisioner "file" {
    source      = "../provision"
    destination = "/vagrant/provision"
  }
  provisioner "file" {
    source      = "../menu"
    destination = "/vagrant/menu"
  }
  provisioner "file" {
    source      = "../soc-lab"
    destination = "/vagrant/soc-lab"
  }
  provisioner "file" {
    source      = "../tools"
    destination = "/vagrant/tools"
  }
  provisioner "file" {
    source      = "../gui"
    destination = "/vagrant/gui"
  }

  # Esegue gli stessi script di provisioning usati da Vagrant
  provisioner "shell" {
    execute_command = "echo 'vagrant' | sudo -S bash '{{ .Path }}'"
    scripts = [
      "../provision/01-tools.sh",
      "../provision/02-ollama.sh",
      "../provision/04-blueteam.sh",
      "../provision/05-cloud-devsecops.sh",
      "../provision/07-adpentest.sh",
      "../provision/06-soclab.sh",
      "../provision/08-utils.sh",
      "../provision/09-gui.sh",
      "../provision/03-menu.sh"
    ]
  }
}
