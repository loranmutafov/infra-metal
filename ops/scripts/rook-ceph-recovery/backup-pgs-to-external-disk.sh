#!/bin/sh
set -eo pipefail

# Grab the preflight.sh functions
. "$(dirname "$0")/preflight.sh"
. "$(dirname "$0")/input.sh"
. "$(dirname "$0")/status.sh"
. "$(dirname "$0")/rook-ceph.sh"
. "$(dirname "$0")/kube.sh"

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
preflightcmd sha256sum
preflightcmd touch
preflightcmd stat
preflightcmd pv

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


# Loop over the array and operate on each element
idempotencykey=$(openssl rand -hex 8)
resumedbackup=false

{
  newidempkey=$(read_input "🦄 Start new backup with generated hash or resume from custom hash" "$idempotencykey")
  if [ -n $newidempkey ] && [ $newidempkey != $idempotencykey ]; then
    idempotencykey="$newidempkey"
    resumedbackup=true
    echo "🦄 Resuming backup with hash: $idempotencykey"
  else
    echo "🦄 Continuing with new backup: $idempotencykey"
  fi
}

# TODO Create JSON file to keep track of backups and their progress
# Backup JSON file format - hash as key, and keep track of shasums of pg files
# {
#   "f85e38d078af9953": {
#     "status": {
#       "last-osd": "4",
#       "last-pg": "0.1",
#       "status": "success",
#       "backup_location": "/Volumes/ExternalDisk/backup",
#       "backup_time": "2023-10-01T12:00:00Z",
#       "backup_duration": "1m30s"
#     },
#     "osd-4": {
#       "osd": "4",
#       "osd_maintenance_pod_name": "rook-ceph-osd-4-maintenance-7f8c6b5f8c-2j9gk",
#       "backup_location": "/Volumes/ExternalDisk/backup",
#       "backup_hash": "f85e38d078af9953",
#       "backup_time": "2023-10-01T12:00:00Z",
#       "backup_duration": "1m30s",
#       "pgs": {
#         "0.0": {
#           "status": "success",
#           "pg_local_hash": "f85e38d078af9953",
#           "pg_remote_hash": "f85e38d078af9953",
#           "local_path": "/Volumes/ExternalDisk/backup/ceph-osd4-pg0.0.f85e38d078af9953.backup",
#           "remote_path": "/var/lib/ceph/osd/ceph-4/0.1.f85e38d078af9953.backup",
#           "pg_local_size": "123456789",
#           "pg_remote_size": "123456789"
#         },
#         "0.1": {
#           "status": "success",
#           "pg_local_hash": "f85e38d078af9953",
#           "pg_remote_hash": "f85e38d078af9953",
#           "local_path": "/Volumes/ExternalDisk/backup/ceph-osd4-pg0.1.f85e38d078af9953.backup",
#           "remote_path": "/var/lib/ceph/osd/ceph-4/0.1.f85e38d078af9953.backup",
#           "pg_local_size": "123456789",
#           "pg_remote_size": "123456789"
#         }
#       }
#     }
#   },
#   "f85e38d078af9954": {
#     "status": {
#       "last-osd": "4",
#       "last-pg": "0.1",
#       "status": "success",
#       "backup_location": "/Volumes/ExternalDisk/backup",
#       "backup_time": "2023-10-01T12:00:00Z",
#       "backup_duration": "1m30s"
#     },
#     "osd-4": {

# }
backup_json_file="$HOME/.rook-ceph-pg-backup-status.json"
touch "$backup_json_file"
backup_json=$(cat "$backup_json_file" | jq ".\"$idempotencykey\"" 2>/dev/null || echo "{}")

function save_backup_status {
  # Save the backup status to the JSON file
  echo
  echo "🧹 Saving the backup status to $backup_json_file"
  jqupdate "$backup_json_file" "$idempotencykey" "$backup_json"
  echo "👍 Backup status saved"
  echo "🦄 To resume this backup, use the following hash when prompted: $idempotencykey"
}

function bailout {
  echo
  echo "🔥 Script crashed or terminated" 2>&1

  save_backup_status

  exit 1
}

trap 'bailout' SIGINT SIGTERM ERR

echo
echo "🔍 Looking for OSDs..."
osds_found=$(ceph_get_osds | newlines_to_commas)
echo "👉 OSDs found: $osds_found"
echo

chosen_osd=$(choose_option "❓ Choose an OSD to run the backups from" "$osds_found" "osd-")
bstat_set_status "last_osd" "$chosen_osd"
echo "👉 Chosen OSD: $chosen_osd"
echo

pgs_to_backup_str=$(bstat_get_osd $chosen_osd "chosen_pgs")
if [ -z "$pgs_to_backup_str" ]; then
  pgs_to_backup_str=$(bstat_get_status "last_chosen_pgs")
fi

pgs_to_backup_str=$(read_input "❓ Which PGS do you want to backup - comma separated, no whitespace" "$pgs_to_backup_str")
echo "👉 PGS to backup: $pgs_to_backup_str"

bstat_set_osd $chosen_osd "chosen_pgs" "$pgs_to_backup_str"
bstat_set_status "last_chosen_pgs" "$pgs_to_backup_str"

# Turn the comma-separated PGs-string into an array
IFS=',' read -r -a pgs_to_backup <<< "$pgs_to_backup_str"

echo
backup_location=$(bstat_get_status "backup_location")
backup_location=$(read_path_input "❓ Where do you want to backup the PGs to" $backup_location)
bstat_set_status "backup_location" "$backup_location"
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
echo "🔍 Getting OSD $chosen_osd's maintenance pod name..."
osd_maintenance_pod_name=$(get_osd_maintenance_pod_name "$chosen_osd")
echo "👉 OSD maintenance pod name: $osd_maintenance_pod_name"

echo
if ! prompt_continue "❓ Are you ready to start the backup"; then
  echo "❌ Backup aborted"
  exit 1
fi

echo
echo "🔂️ Starting backup of PGs from OSD $chosen_osd to $backup_location..."

logdir="/tmp/rook-ceph-backups/logs/$idempotencykey"
mkdir -p $logdir
echo "🪵 Log directory: $logdir"

save_backup_status
echo

some_failed=false
for pg in "${pgs_to_backup[@]}"; do
  bs_pg_remote_hash=$(bstat_get_pg $chosen_osd $pg "pg_remote_hash")
  bs_pg_local_hash=$(bstat_get_pg $chosen_osd $pg "pg_local_hash")
  bs_pg_remote_size=$(bstat_get_pg $chosen_osd $pg "pg_remote_size")
  bs_pg_local_size=$(bstat_get_pg $chosen_osd $pg "pg_local_size")

  pg_backup_filename="ceph-osd${chosen_osd}-pg${pg}.$idempotencykey.backup"

  should_export=true
  # If remote hash and size, skip export
  if [ "$resumedbackup" = true ] && [ -n "$pg_remote_hash" ] && [ -n "$pg_remote_size" ]; then
    echo
    echo "🦘 Backup file hash and size already recorded"
    echo "🫆  Remote hash: $bs_pg_remote_hash"
    echo "📏 Remote size: $bs_pg_remote_size"
    echo "🫆  Local hash: $bs_pg_local_hash"
    echo "📏 Local size: $bs_pg_local_size"

    hashes_match=false
    sizes_match=false
    if [ "$bs_pg_local_hash" = "$bs_pg_remote_hash" ]; then
      hashes_match=true
    fi
    if [ "$bs_pg_local_size" = "$bs_pg_remote_size" ]; then
      sizes_match=true
    fi

    if [ "$hashes_match" = true ] && [ "$sizes_match" = true ]; then
      echo "🫱🏻‍🫲🏿 Hash and size records match, checking against local copies..."

      if [ -f "$backup_location/$pg_backup_filename" ]; then
        echo "🚏 Local backup file exists, checking integrity..."
        pg_local_size=$(stat -f %z "$backup_location/$pg_backup_filename")
        pg_local_hash=$(sha256sum "$backup_location/$pg_backup_filename" | awk '{print $1}')

        if [ "$pg_local_hash" = "$bs_pg_remote_hash" ] && [ "$pg_local_size" = "$bs_pg_remote_size" ]; then
          echo "⚖️ Integrity check passed, local file is valid"
          echo "🦘 Skipping export of PG $pg on OSD $chosen_osd"

          continue
        else
          echo "🏴‍☠️ Local backup file hash or size do not match our records, running remote file integrity checks..."
        fi
      else
        echo "🙈 No local backup file found, running remote file integrity checks..."
      fi
    else
      echo "👮 Hashes or sizes do not match actual files', running remote file integrity checks..."
    fi

    # Check if remote file exists
    if kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- stat $pg_backup_filename &> /dev/null; then
      echo "🕵🏻 Remote backup file exists, checking its integrity against our records..."

      pg_remote_size=$(kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- stat -c %s $pg_backup_filename 2> $logdir/kube-stat.pg${pg}.log)
      pg_remote_hash=$(kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- sha256sum $pg_backup_filename 2> $logdir/kube-shasum.pg${pg}.log | awk '{print $1}')

      echo "🫆  Remote backup hash: $pg_remote_hash"
      echo "📏 Remote backup size: $pg_remote_size"

      if [ "$pg_remote_hash" = "$bs_pg_remote_hash" ] && [ "$pg_remote_size" = "$bs_pg_remote_size" ]; then
        echo "⚖️ Remote backup file is valid, skipping export"
        should_export=false
      else
        echo "🏴‍☠️ Remote backup file hash or size do not match our records, we should export the PG again"
      fi
    else
      echo "🙂‍↔️ Remote backup file does not exist, we should export the PG again"
      should_export=true
    fi
  fi

  if [ "$should_export" = true ]; then
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

    pg_remote_size=$(kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- stat -c %s $pg_backup_filename 2> $logdir/kube-stat.pg${pg}.log)
    bstat_set_pg $chosen_osd $pg "pg_remote_size" "$pg_remote_size"
    echo "📏 Remote file size in bytes: $pg_remote_size"

    echo "🔐 Getting hash of export file..."
    pg_remote_hash=$(kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- sha256sum $pg_backup_filename 2> $logdir/kube-shasum.pg${pg}.log | awk '{print $1}')
    bstat_set_pg $chosen_osd $pg "pg_remote_hash" "$pg_remote_hash"
    echo "🫆  Remote export hash: $pg_remote_hash"
  fi

  local_backup_path="$backup_location/$pg_backup_filename"
  echo "📦 Local backup path: $local_backup_path"
  bstat_set_pg $chosen_osd $pg "local_backup_path" "$local_backup_path"

  need_to_copy=true
  if [ "$resumedbackup" = true ] && [ -f $local_backup_path ]; then
    echo "🫵 Backup file already exported, checking integrity..."

    pg_local_hash=$(sha256sum $local_backup_path | awk '{print $1}')
    pg_local_size=$(stat -f %z $local_backup_path)

    echo "🫆  Local backup hash: $pg_local_hash"
    echo "📏 Local file size in bytes: $pg_local_size"

    if [ "$pg_local_hash" != "$pg_remote_hash" ] && [ "$pg_local_size" != "$pg_remote_size" ]; then
      echo "♻️ Hash and size do not match, we should redownload the file"
    elif [ "$pg_local_hash" = "$pg_remote_hash" ] && [ "$pg_local_size" = "$pg_remote_size" ]; then
      echo "⚖️ Hashes and sizes match, we can skip downloading the file"
      need_to_copy=false
    else
      echo "🕵  Either the hash or size do not match (which while not impossible, is rather bizarre), we need to download the file again"
    fi
  fi

  if [ "$need_to_copy" = true ]; then
    echo "🚚 Copying backup file to $local_backup_path..."
    kube_cp_pv_fifo rook-ceph "$osd_maintenance_pod_name" "$pg_backup_filename" "$local_backup_path" "$pg_remote_size" "$logdir/kube-cp.pg${pg}.log" || \
    {
      echo "❌ Copy of PG $pg on OSD $chosen_osd failed"
      some_failed=true
      continue
    }
  else
    echo "🦘 Backup file already exists and is identical, skipping copy"
  fi

  # kubectl cp -n rook-ceph "$osd_maintenance_pod_name":$pg_backup_filename $local_backup_path --retries 10 &> $logdir/kube-cp.pg${pg}.log

  pg_local_hash=$(sha256sum $local_backup_path | awk '{print $1}')
  pg_local_size=$(stat -f %z $local_backup_path)

  echo "🫆  Local backup hash: $pg_local_hash"
  echo "📏 Local file size in bytes: $pg_local_size"

  if [ "$pg_local_hash" != "$pg_remote_hash" ] || [ "$pg_local_size" != "$pg_remote_size" ]; then
    echo "❌ Backup file hashes or sizes do not match"
    some_failed=true
    continue
  fi
  echo "🫱‍🫲 Backup file hashes match"

  echo "🔪 Removing backup file from OSD $chosen_osd..."
  kubectl exec -n rook-ceph "$osd_maintenance_pod_name" -- rm $pg_backup_filename &> $logdir/kube-rm.pg${pg}.log

  # Store local hash and size
  bstat_set_pg $chosen_osd $pg "pg_local_hash" "$pg_local_hash"
  bstat_set_pg $chosen_osd $pg "pg_local_size" "$pg_local_size"

  echo "✅ PG $pg on OSD $chosen_osd backup successful: $pg_backup_filename"
done

echo
if [ "$some_failed" = true ]; then
  echo "⚠️ Script finished, but some backups failed - please check the output above for more details"
  exit 1
else
  echo "🎉 All backups completed successfully 🎉"

  save_backup_status
fi
