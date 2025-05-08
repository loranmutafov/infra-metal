#!/bin/sh
set -eo pipefail

# Grab the preflight.sh functions
. "$(dirname "$0")/preflight.sh"
. "$(dirname "$0")/input.sh"
. "$(dirname "$0")/utils.sh"
. "$(dirname "$0")/rook-ceph.sh"

echo
echo "🛫 Running pre-flight checks..."
echo

preflight_passed=true

function preflightcmd {
  if cmdexists "$1" ; then
    echo "👍 $1 command found"
  else
    echo "❌ $1 command not found"
    preflight_passed=false
  fi
}

preflightcmd wc
preflightcmd jq
preflightcmd tr
preflightcmd sed
preflightcmd awk
preflightcmd openssl
preflightcmd kubectl

if kubectl_rook_ceph_plugin_installed; then
  echo "👍 kubectl rook-ceph plugin installed"
else
  echo "❌ kubectl rook-ceph plugin not installed"
  preflight_passed=false
fi

if rook_ceph_cluster_exists; then
  echo "👍 Rook Ceph cluster exists"
else
  echo "❌ Rook Ceph cluster does not exist"
  preflight_passed=false
fi

echo
if [ "$preflight_passed" = true ]; then
  echo "✅ Preflight checks passed"
  echo
else
  echo "🔥 Preflight checks failed, aborting" 2>&1
  exit 1
fi

if ! prompt_continue "❓ Do you want to continue with the backup"; then
  echo "❌ Backup aborted"
  exit 1
fi

# TODO Create JSON file to keep track of backups and their progress
backup_json_file="~/.rook-ceph-pgs-to-external-disk.json"


echo
echo "🔍 Looking for OSDs..."
osds_found=$(ceph_get_osds | newlines_to_commas)
echo "👉 OSDs found: $osds_found"
echo

chosen_osd=$(choose_option "❓ Choose an OSD to run the backups from" "$osds_found" "osd-")
echo "👉 Chosen OSD: $chosen_osd"
echo

pgs_to_backup_str=$(read_input "❓ Which PGS do you want to backup (comma separated)")
echo "👉 PGS to backup: $pgs_to_backup_str"

# Turn the comma-separated PGs-string into an array
IFS=',' read -r -a pgs_to_backup <<< "$pgs_to_backup_str"

echo
backup_location=$(read_path_input "❓ Where do you want to backup the PGs to (e.g., /Volumes/ExternalDisk/backup)")
echo "👉 Backup location: $backup_location"

if [ ! -d "$backup_location" ]; then
  echo "❌ Backup location does not exist"
  exit 1
fi

# Check if OSD is in maintenance mode
echo "🔍 Checking if OSD is in maintenance mode..."
osd_maintenance=$(is_osd_maintenance "$chosen_osd")

# If the OSD is in maintenance mode, prompt the user to continue
if [[ "$osd_maintenance" == "true" ]]; then
  echo "✅️ OSD $chosen_osd is already in maintenance mode"
else
  echo "❌ OSD $chosen_osd is not in maintenance mode"

  echo
  echo "To put the OSD in maintenance mode:"
  echo "👉 kubectl rook-ceph maintenance start rook-ceph-osd-$chosen_osd"

  exit 1
fi

echo
if ! prompt_continue "❓ Do you want to continue with the backup"; then
  echo "❌ Backup aborted"
  exit 1
fi

echo
echo "🔍 Getting OSD $chosen_osd's maintenance pod name..."
osd_maintenance_pod_name=$(get_osd_maintenance_pod_name "$chosen_osd")
echo "👉 OSD maintenance pod name: $osd_maintenance_pod_name"

echo
echo "🔂️ Starting backup of PGs from OSD $chosen_osd to $backup_location..."

# Loop over the array and operate on each element
idempotencykey=$(openssl rand -hex 8)
resumedbackup=false
echo "🦄 Generated unique backup hash: $idempotencykey"

if prompt_continue "❓ Do you want to resume a backup from a different hash (press n if unsure)"; then
  idempotencykey=$(read_input "❓ Please enter the hash of the backup you'd like to resume")
  echo "🦄 Resuming backup for hash: $idempotencykey"
  resumedbackup=true
fi

logdir="/tmp/rook-ceph-backups/logs/$idempotencykey"
mkdir -p $logdir
echo "🪵 Log directory: $logdir"

some_failed=false
for pg in "${pgs_to_backup[@]}"; do
  pg_backup_filename="ceph-osd${chosen_osd}-pg${pg}.$idempotencykey.backup"

  echo
  echo "🎬 Exporting PG $pg on OSD $chosen_osd..."
  # kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-$chosen_osd --pgid $pg --op info 2> /dev/null
  kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-$chosen_osd --pgid $pg --op export --file $pg_backup_filename 2> $logdir/kube-ceph-export.pg${pg}.log || \
  {
    echo "❌ Export of PG $pg on OSD $chosen_osd failed"
    some_failed=true
    continue
  }
  echo "🙂‍↕️ Export of PG $pg on OSD $chosen_osd completed"

  echo "🔐 Getting hash of export file..."
  remote_backup_hash=$(kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- sha256sum $pg_backup_filename 2> $logdir/kube-shasum.pg${pg}.log | awk '{print $1}')
  echo "🫆  Remote export hash: $remote_backup_hash"

  local_backup_path="$backup_location/$pg_backup_filename"

  if [ "$resumedbackup" = true ] && [ -f $local_backup_path ]; then
    echo "🫵 Backup file already exists, checking hash against remote..."
    local_backup_hash=$(sha256sum $local_backup_path | awk '{print $1}')
    echo "🫆  Local backup hash: $local_backup_hash"
    if [ "$local_backup_hash" == "$remote_backup_hash" ]; then
      echo "🦘 Backup file hashes match, skipping copy"
      echo "🔪 Removing backup file from OSD $chosen_osd..."
      kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- rm $pg_backup_filename &> $logdir/kube-rm.pg${pg}.log
      continue
    else
      echo "♻️ Hashes do not match, continuing to copy backup file to $local_backup_path..."
    fi
  fi

  echo "🚚 Copying backup file to $local_backup_path..."
  kubectl cp -n rook-ceph "$osd_maintenance_pod_name":$pg_backup_filename $local_backup_path --retries 10 &> $logdir/kube-cp.pg${pg}.log

  local_backup_hash=$(sha256sum $local_backup_path | awk '{print $1}')
  echo "🫆  Local backup hash: $local_backup_hash"

  if [ "$local_backup_hash" != "$remote_backup_hash" ]; then
    echo "❌ Backup file hashes do not match"
    some_failed=true
    continue
  fi
  echo "🫱‍🫲 Backup file hashes match"

  echo "🔪 Removing backup file from OSD $chosen_osd..."
  kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- rm $pg_backup_filename &> $logdir/kube-rm.pg${pg}.log

  echo "✅ PG $pg on OSD $chosen_osd backup successful: $pg_backup_filename"
done

echo
if [ "$some_failed" = true ]; then
  echo "⚠️ Script finished, but some backups failed - please check the output above for more details"
  exit 1
else
  echo "🎉 All backups completed successfully 🎉"
fi
