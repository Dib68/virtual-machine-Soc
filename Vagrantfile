# -*- mode: ruby -*-
# vi: set ft=ruby :
# ============================================================================
#  CyberSec AI VM  -  Vagrantfile per VirtualBox
#  VM Kali Linux con tool red+blue team, AI locale, menu e GUI moderna.
#  USO:  vagrant up | vagrant ssh | vagrant halt | vagrant destroy
# ============================================================================

Vagrant.configure("2") do |config|
  config.vm.box = "kalilinux/rolling"
  config.vm.hostname = "cybersec-ai"

  # Rete privata host-only (lab isolato e sicuro: mai esporre i bersagli!)
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "CyberSec-AI-VM"
    vb.gui    = true
    vb.memory = 10240
    vb.cpus   = 4
    vb.customize ["modifyvm", :id, "--vram", "128"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--accelerate3d", "off"]
    vb.customize ["modifyvm", :id, "--clipboard-mode", "bidirectional"]
    vb.customize ["modifyvm", :id, "--draganddrop", "bidirectional"]
    vb.customize ["modifyvm", :id, "--nested-hw-virt", "on"]
  end

  # Cartella condivisa host <-> VM
  config.vm.synced_folder "./condivisa", "/home/vagrant/condivisa", create: true

  # Disco piu' grande (richiede: vagrant plugin install vagrant-disksize)
  if Vagrant.has_plugin?("vagrant-disksize")
    config.disksize.size = "60GB"
  end

  # -------------------- PROVISIONING (in ordine) --------------------
  config.vm.provision "tools",     type: "shell", path: "provision/01-tools.sh",          privileged: true
  config.vm.provision "ai",        type: "shell", path: "provision/02-ollama.sh",         privileged: true
  config.vm.provision "blueteam",  type: "shell", path: "provision/04-blueteam.sh",       privileged: true
  config.vm.provision "cloud",     type: "shell", path: "provision/05-cloud-devsecops.sh", privileged: true
  config.vm.provision "adpentest", type: "shell", path: "provision/07-adpentest.sh",      privileged: true
  config.vm.provision "soclab",    type: "shell", path: "provision/06-soclab.sh",         privileged: true
  config.vm.provision "utils",     type: "shell", path: "provision/08-utils.sh",          privileged: true
  config.vm.provision "gui",       type: "shell", path: "provision/09-gui.sh",            privileged: true
  config.vm.provision "menu",      type: "shell", path: "provision/03-menu.sh",           privileged: true

  config.vm.post_up_message = <<-MSG

  ============================================================
   CyberSec AI VM pronta!  (login: vagrant / vagrant)
  ------------------------------------------------------------
   GUI moderna:  doppio clic su "CyberSec Control Center"
                 (sul Desktop) oppure digita:  cybergui
   Menu testuale: cybermenu       Assistente AI: ai
   SOC lab:       soclab targets up
  ============================================================

  MSG
end
