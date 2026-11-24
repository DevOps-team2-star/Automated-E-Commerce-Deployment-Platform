#!/usr/bin/env bash
# Installs every CLI the project needs inside WSL2 Ubuntu (24.04).
# Docker itself comes from Docker Desktop (Settings > Resources > WSL integration > Ubuntu ON).
# Safe to re-run: each tool is skipped if already present.
set -euo pipefail

BIN=/usr/local/bin
ARCH=amd64
need() { ! command -v "$1" >/dev/null 2>&1; }
warn() { echo "WARNING: $*" >&2; }

echo "==> apt packages"
sudo apt-get update -y
sudo apt-get install -y curl unzip jq git gnupg ca-certificates python3-pip pipx software-properties-common lsb-release

if need kubectl; then
  echo "==> kubectl"
  v=$(curl -Ls https://dl.k8s.io/release/stable.txt)
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${v}/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl $BIN/kubectl
fi

if need k3d; then
  echo "==> k3d"
  curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

if need helm; then
  echo "==> helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

if need kustomize; then
  echo "==> kustomize"
  (cd /tmp && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash)
  sudo install -m 0755 /tmp/kustomize $BIN/kustomize
fi

if need terraform; then
  echo "==> terraform (HashiCorp apt repo)"
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/hashicorp.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  sudo apt-get update -y && sudo apt-get install -y terraform
fi

if need ansible; then
  echo "==> ansible"
  pipx install --include-deps ansible
  pipx inject ansible kubernetes
  pipx ensurepath
fi

if need aws; then
  echo "==> aws cli v2"
  curl -fsSLo /tmp/awscliv2.zip "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
  (cd /tmp && unzip -qo awscliv2.zip && sudo ./aws/install --update)
fi

if need hey; then
  echo "==> hey (load generator, Ubuntu package)"
  sudo apt-get install -y hey || warn "hey not installed: load tests (hpa-demo, rollback-demo) need it"
fi

if need hadolint; then
  echo "==> hadolint (Dockerfile linter)"
  if curl -fsSLo /tmp/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64; then
    sudo install -m 0755 /tmp/hadolint $BIN/hadolint
  else
    warn "hadolint not installed: only the Jenkins Lint stage uses it (the Jenkins image has its own)"
  fi
fi

echo "==> done. Open a new shell (or: source ~/.bashrc) for the pipx PATH, then run ./scripts/check-tools.sh"
