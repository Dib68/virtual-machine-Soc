#!/bin/bash
# Target machine setup — called by docker-compose entrypoint
# Installs SSH + nginx and creates lab users (labuser:labpass, root:toor)
# This file exists as a reference; the actual setup runs inline in docker-compose.yml

echo "Target machine provisioning complete."
echo "  SSH  → port 22 (labuser:labpass / root:toor)"
echo "  HTTP → port 80 (nginx)"
