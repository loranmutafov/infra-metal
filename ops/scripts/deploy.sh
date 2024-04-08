#!/usr/bin/env sh
set -eo pipefail

echo "🤞 Updating metal"

GIT_REV=$(git rev-parse --short=8 HEAD)
TMP_DIR=$(mktemp -d -t infra-metal-$GIT_REV.XXXXXXXX)

cleanup() {
  # Remove temp dir
  rm -rf "${TMP_DIR}"
  echo "Temp directory removed"
}

bailout() {
  echo "🔥 Error, deleting temp directory" 2>&1

  cleanup
}

trap 'bailout' SIGINT SIGTERM ERR

# OnePassword injections
op inject \
  -i ./machines/gustav/cloudflared-2023.10.0.tpl \
  -o ${TMP_DIR}/cloudflared-2023.10.0

pushd "./machines"
  nix-shell -p colmena --run "colmena apply"
popd

cleanup
echo "🤘 Metal updated"
