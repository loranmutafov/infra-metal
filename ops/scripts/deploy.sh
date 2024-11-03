#!/usr/bin/env sh
set -eo pipefail

# This script is used to deploy the infrastructure to the metal cloud.
. $(dirname "$0")/helper.sh

echo "🤞 Updating metal"
echo
echo "Directory: $(dirname "$0")"
echo

echo "🔍 Preflight checks"
preflight_passed=true
preflight_os || preflight_passed=false
preflight_pkg nix-shell || preflight_passed=false
preflight_pkg tailscale || preflight_passed=false

if [ "$preflight_passed" = true ]; then
  echo "✅ Preflight checks passed"
  echo
else
  echo "🔥 Error: Preflight checks failed, aborting" 2>&1
  exit 1
fi

WAS_TAILSCALE_CONNECTED=false

echo "🔌 Checking tailscale connection"
if is_tailscale_connected; then
  WAS_TAILSCALE_CONNECTED=true
  echo "✅ Tailscale already connected"
else
  echo "⚡️ Connecting tailscale"
  tailscale_cmd up

  if is_tailscale_connected; then
    echo "✅ Tailscale connected"
  else
    echo "🔥 Error: Tailscale connection failed" 2>&1
    exit 1
  fi
fi

GIT_REV=$(git rev-parse --short=8 HEAD)
TMPDIR=/private/tmp
TMP_DIR=$(mktemp -d -t infra-metal-$GIT_REV.XXXXXXXX)

cleanup() {
  echo
  echo "🧹 Cleaning up"

  # Remove temp dir
  rm -rf "${TMP_DIR}"
  echo "🔪 Temp directory removed"

  if ! $WAS_TAILSCALE_CONNECTED; then
    echo "🔌 Disconnecting tailscale"
    tailscale_cmd down
  fi

  echo "✅ Cleanup complete"
}

bailout() {
  echo "☠︎ Error: Deployment likely unsuccessful" 2>&1

  cleanup
}

trap 'bailout' SIGINT SIGTERM ERR

echo
echo "🚀 Deploying machines"
echo

pushd "./machines" > /dev/null
  nix-shell -p colmena --run "colmena --show-trace apply $@"
popd

cleanup

echo
echo "🤘 Metal updated"
