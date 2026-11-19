#!/usr/bin/env bash
set -euo pipefail

module_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
assets=(webhook.zip runners.zip runner-binaries-syncer.zip termination-watcher.zip)
upstream=github-aws-runners/terraform-aws-github-runner
version=$(awk -F '"' '
  /^module "runners" \{/ { runners = 1 }
  runners && /^[[:space:]]*version[[:space:]]*=/ { print $2; exit }
  /^\}/ { runners = 0 }
' "$module_dir/main.tf")
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo 'Expected an exact version in the runners Terraform module.' >&2
  exit 1
fi
tag="v$version"

cd "${1:?Pass the ephemeral runner Terraform directory}"
commit=$(gh api --hostname github.com "repos/$upstream/commits/$tag" --jq .sha)
if [[ ! $commit =~ ^[0-9a-f]{40}$ ]]; then
  echo "Could not resolve upstream runner release $tag to a commit." >&2
  exit 1
fi

dir=.terraform/runner-artifacts
mkdir -p "$dir"
download=$(mktemp -d "$dir/download.XXXXXX")
cleanup() {
  for asset in "${assets[@]}" bundle.json; do
    rm -f -- "$download/$asset"
  done
  rmdir "$download"
}
trap cleanup EXIT

patterns=()
for asset in "${assets[@]}"; do
  patterns+=(--pattern "$asset")
done
gh release download "$tag" --repo "github.com/$upstream" --dir "$download" "${patterns[@]}"
gh release download "$tag" --repo "github.com/$upstream" \
  --pattern '*-attestation-*.sigstore' --output "$download/bundle.json"

for asset in "${assets[@]}"; do
  gh attestation verify "$download/$asset" --repo "$upstream" --bundle "$download/bundle.json" \
    --signer-workflow "$upstream/.github/workflows/release.yml" \
    --source-ref refs/heads/main --source-digest "$commit" --deny-self-hosted-runners
done
for asset in "${assets[@]}"; do
  mv "$download/$asset" "$dir/$asset"
done
