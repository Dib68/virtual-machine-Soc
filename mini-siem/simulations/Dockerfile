FROM kalilinux/kali-rolling

# Attack tools for MITRE ATT&CK simulations
RUN apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    nmap \
    hydra \
    nikto \
    curl \
    sshpass \
    openssh-client \
    python3 \
    iputils-ping \
    net-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /simulations

# Default: show available tools
CMD ["bash", "-c", "echo 'Attacker container ready. Run: docker run --rm --network siem-net siem-attacker bash /simulations/<script>.sh'"]
