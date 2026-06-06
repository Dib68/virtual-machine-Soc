#!/usr/bin/env bash
# ============================================================================
#  05-cloud-devsecops.sh  -  Cloud Security & DevSecOps
#  Tool sempre piu' richiesti: CLI cloud (AWS/Azure/GCP), Kubernetes,
#  Terraform/IaC e scanner di sicurezza cloud/container.
# ============================================================================
set -uo pipefail
export DEBIAN_FRONTEND=noninteractive

FAILED=()
note() { echo "    !! $1 non installato"; FAILED+=("$1"); }

apt-get update -y
apt-get install -y unzip curl gnupg lsb-release ca-certificates apt-transport-https || true

echo "==> AWS CLI v2..."
if ! command -v aws >/dev/null 2>&1; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscli.zip \
    && unzip -q /tmp/awscli.zip -d /tmp && /tmp/aws/install --update || note awscli
fi

echo "==> Azure CLI..."
if ! command -v az >/dev/null 2>&1; then
  curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash || note azure-cli
fi

echo "==> Google Cloud CLI..."
if ! command -v gcloud >/dev/null 2>&1; then
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null || true
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list
  apt-get update -y && apt-get install -y google-cloud-cli || note google-cloud-cli
fi

echo "==> Kubernetes: kubectl + helm + minikube..."
if ! command -v kubectl >/dev/null 2>&1; then
  KV=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
  curl -fsSL "https://dl.k8s.io/release/${KV}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl || note kubectl
fi
if ! command -v helm >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || note helm
fi

echo "==> Terraform (IaC)..."
if ! command -v terraform >/dev/null 2>&1; then
  curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp.gpg 2>/dev/null || true
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs 2>/dev/null || echo bookworm) main" \
    > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -y && apt-get install -y terraform || note terraform
fi

echo "==> Scanner cloud / container / IaC..."
# Trivy (container/IaC/secret scanner) - molto richiesto
apt-get install -y trivy || note trivy
# Scanner via pip (best effort)
pip3 install --break-system-packages --quiet \
  scoutsuite prowler checkov 2>/dev/null || true
# tfsec / kube-bench / kube-hunter via binari best effort
GO_TOOLS_OK=1
command -v tfsec   >/dev/null 2>&1 || GO_TOOLS_OK=0
# kube-bench / kube-hunter sono spesso usati come container Docker (vedi soc-lab)

# Registra mancanti
mkdir -p /opt/cybersec
if [ ${#FAILED[@]} -gt 0 ]; then
  printf '%s\n' "${FAILED[@]}" >> /opt/cybersec/missing_tools.txt
fi

echo "==> Cloud & DevSecOps: installazione completata."
echo "    (ScoutSuite, Prowler, Checkov installati via pip se la rete lo ha permesso)"
