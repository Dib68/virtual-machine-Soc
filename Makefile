# Makefile - scorciatoie per la CyberSec AI VM
.PHONY: help up down ssh reload provision destroy ova status snapshot restore

help:
	@echo "Comandi disponibili:"
	@echo "  make up         - crea/avvia la VM (vagrant up)"
	@echo "  make down       - spegne la VM"
	@echo "  make ssh        - accesso SSH alla VM"
	@echo "  make reload     - riavvia la VM"
	@echo "  make provision  - riesegue gli script di installazione"
	@echo "  make ova        - genera l'immagine .ova distribuibile"
	@echo "  make snapshot   - crea uno snapshot 'clean'"
	@echo "  make restore    - ripristina lo snapshot 'clean'"
	@echo "  make status     - stato della VM"
	@echo "  make destroy    - elimina la VM"

up:        ; vagrant up
down:      ; vagrant halt
ssh:       ; vagrant ssh
reload:    ; vagrant reload
provision: ; vagrant provision
destroy:   ; vagrant destroy -f
status:    ; vagrant status
ova:       ; bash build-ova.sh
snapshot:  ; vagrant snapshot save clean
restore:   ; vagrant snapshot restore clean
