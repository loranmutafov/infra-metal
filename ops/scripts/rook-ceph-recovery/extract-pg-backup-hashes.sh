#!/bin/bash

# Extract PG remote hash and size from Ceph backup JSON
# Only shows PGs where remote hash/size matches local hash/size
# Usage: ./extract-pg-backup-hashes.sh <backup_hash> <osd_num> <pg_id1,pg_id2,pg_id3>

if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <backup_hash> <osd_num> <pg_id1,pg_id2,pg_id3>"
    echo "Example: $0 3f2ce993c7282b69 2 1.4b,1.47,1.40"
    exit 1
fi

BACKUP_HASH="$1"
OSD_NUM="$2"
IFS=',' read -ra PG_IDS <<< "$3"

JSON_FILE="$HOME/.rook-ceph-pg-backup-status.json"

if [[ ! -f "$JSON_FILE" ]]; then
    echo "JSON file not found: $JSON_FILE"
    exit 1
fi

echo -e "PG\tHash\tSize(bytes)"
echo -e "---\t---\t---"

# Process each requested PG
for pg in "${PG_IDS[@]}"; do
    # Extract PG data using simple jq queries
    pg_data=$(jq -r ".\"$BACKUP_HASH\".\"osd-$OSD_NUM\".pgs.\"$pg\"" "$JSON_FILE" 2>/dev/null)

    if [[ "$pg_data" == "null" || -z "$pg_data" ]]; then
        echo -e "$pg\tNOT FOUND\t-"
        continue
    fi

    # Get individual fields
    remote_hash=$(echo "$pg_data" | jq -r '.pg_remote_hash // empty')
    local_hash=$(echo "$pg_data" | jq -r '.pg_local_hash // empty')
    remote_size=$(echo "$pg_data" | jq -r '.pg_remote_size // empty')
    local_size=$(echo "$pg_data" | jq -r '.pg_local_size // empty')

    # Check if we have all required data
    if [[ -z "$remote_hash" || -z "$local_hash" || -z "$remote_size" || -z "$local_size" ]]; then
        echo -e "$pg\tINCOMPLETE DATA\t-"
        continue
    fi

    # Check if hashes and sizes match
    if [[ "$remote_hash" == "$local_hash" && "$remote_size" == "$local_size" ]]; then
        echo -e "$pg\t$remote_hash\t$remote_size"
    else
        echo -e "$pg\tMISMATCH\t-"
    fi
done | column -t