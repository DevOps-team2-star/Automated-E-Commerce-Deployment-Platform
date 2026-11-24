#!/usr/bin/env bash
# Prints the version of every tool the project uses and fails if one is missing.
set -u
fail=0
check() {
  local name=$1; shift
  if out=$("$@" 2>&1 | head -n 1); then
    printf '  %-10s OK   %s\n' "$name" "$out"
  else
    printf '  %-10s MISSING\n' "$name"; fail=1
  fi
}
echo "Tool check"
check docker    docker version --format '{{.Server.Version}}'
check compose   docker compose version --short
check git       git --version
check kubectl   kubectl version --client
check k3d       k3d version
check helm      helm version --short
check kustomize kustomize version
check terraform terraform version
check ansible   ansible --version
check aws       aws --version
check jq        jq --version
check hey       bash -c 'command -v hey'
check hadolint  hadolint --version
exit $fail
