#!/opt/homebrew/bin/bash

# Check for required commands
for cmd in kubectl jq docker parallel; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is required but not installed"
        exit 1
    fi
done

DEDUPE_HASH=$(openssl rand -hex 8)

# Variables
OSD_POD="$1"
NAMESPACE="$2"
MEMGRAPH_CONTAINER="$3"
OSD_ID=$(echo "$OSD_POD" | sed 's/.*osd-\([0-9]*\).*/\1/')
DATA_PATH="/var/lib/ceph/osd/ceph-$OSD_ID"
LOG_FILE="/tmp/memgraph_insert_$DEDUPE_HASH.log"
TEMP_CYPHER_DIR="/tmp/cypher_$DEDUPE_HASH"

# Validate input
if [ -z "$OSD_POD" ] || [ -z "$NAMESPACE" ] || [ -z "$MEMGRAPH_CONTAINER" ]; then
    echo "Usage: $0 <osd_pod_name> <namespace> <memgraph_container_name>"
    exit 1
fi

# Ensure OSD pod is accessible
if ! kubectl -n "$NAMESPACE" get pod "$OSD_POD" >/dev/null 2>&1; then
    echo "Error: OSD pod $OSD_POD not found in namespace $NAMESPACE"
    exit 1
fi

# Ensure Memgraph container is running
if ! docker ps | grep -q "$MEMGRAPH_CONTAINER"; then
    echo "Error: Memgraph container $MEMGRAPH_CONTAINER not running"
    exit 1
fi

# Clear log file and create temp directory
: > "$LOG_FILE"
mkdir -p "$TEMP_CYPHER_DIR"

# Check Memgraph storage directory
echo "Checking Memgraph storage directory..." | tee -a "$LOG_FILE"
docker exec "$MEMGRAPH_CONTAINER" ls -ld /var/lib/memgraph >>"$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Cannot access /var/lib/memgraph in container. Check $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

# Check for WAL and snapshot files
echo "Checking for WAL and snapshot files..." | tee -a "$LOG_FILE"
docker exec "$MEMGRAPH_CONTAINER" ls -l /var/lib/memgraph/*.wal /var/lib/memgraph/*.snapshot >>"$LOG_FILE" 2>&1

# Test Memgraph connectivity
echo "Testing Memgraph connectivity..." | tee -a "$LOG_FILE"
echo "SHOW CONFIG;" | docker exec -i "$MEMGRAPH_CONTAINER" mgconsole >>"$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to Memgraph. Check $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi
echo "Memgraph connectivity OK" | tee -a "$LOG_FILE"

# Create OSD node
echo "Creating OSD node for ID $OSD_ID" | tee -a "$LOG_FILE"
echo "BEGIN; MERGE (o:OSD {id: '$OSD_ID'}) ON CREATE SET o.created_at = timestamp(), o.name = 'osd-$OSD_ID'; COMMIT;" \
  | docker exec -i "$MEMGRAPH_CONTAINER" mgconsole --host localhost --port 7687 >>"$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    echo "Error: Failed to execute OSD node creation query. Check $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi
echo "OSD node created"

op_list=$(kubectl -n "$NAMESPACE" exec "$OSD_POD" -- ceph-objectstore-tool --data-path "$DATA_PATH" --op list)
if [ $? -ne 0 ]; then
    echo "Error: Failed to list objects for PG $PG_ID. Check $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi
echo "Objects in OSD-$OSD_ID: $op_list" | tee -a "$LOG_FILE"

# Parse JSON and insert objects into Memgraph

echo "Splitting object list into PGs..." | tee -a "$LOG_FILE"

pg_object_pairs=$(echo "$op_list" | jq -c -r -s '
    # Group by first element (PG ID)
    group_by(.[0]) |
    map({
        pg_id: .[0][0],
        objects: map(.[1].oid) | join(" ")
    }) |
    .[] |
    "\(.pg_id)\t\(.objects)"
')

echo "Processing PG objects..." | tee -a "$LOG_FILE"

# Function to process objects for a single PG
process_pg_objects() {
    local PG_ID="$1"
    shift
    local objects="$@"
    local query_file="$TEMP_CYPHER_DIR/pg_${PG_ID}_insert.cypher"

    object_count=$(echo "$objects" | wc -w)

    echo "Generating query for PG $PG_ID" | tee -a "$LOG_FILE"

    local CYPHER_QUERY="BEGIN;"
    CYPHER_QUERY="$CYPHER_QUERY MATCH (o:OSD {id: '$OSD_ID'})"
    CYPHER_QUERY="$CYPHER_QUERY MERGE (p:PG {id: '$PG_ID'}) ON CREATE SET p.created_at = timestamp(), p.name = 'PG $PG_ID' MERGE (o)-[:CONTAINS]->(p);"
    CYPHER_QUERY="$CYPHER_QUERY COMMIT;"
    echo $CYPHER_QUERY | docker exec -i "$MEMGRAPH_CONTAINER" mgconsole --host localhost --port 7687 >>"$LOG_FILE" 2>&1

    CYPHER_QUERY="BEGIN;"
    for object_name in $objects; do
        [ -z "$object_name" ] && continue # Skip empty
        echo "Inserting into PG $PG_ID -> Object $object_name" | tee -a "$LOG_FILE"

        CYPHER_QUERY="$CYPHER_QUERY MATCH (o:OSD {id: '$OSD_ID'}) MATCH (p:PG {id: '$PG_ID'})"
        CYPHER_QUERY="$CYPHER_QUERY MERGE (b:Object {id: '$object_name'})-[:IS]->(ub:UniqueObject {id: '$OSD_ID-$object_name'})"
        CYPHER_QUERY="$CYPHER_QUERY ON CREATE SET"
        CYPHER_QUERY="$CYPHER_QUERY b.created_at = timestamp(), b.name = 'Obj $object_name',"
        CYPHER_QUERY="$CYPHER_QUERY ub.created_at = timestamp(), ub.name = '[$OSD_ID] Obj $object_name'"
        CYPHER_QUERY="$CYPHER_QUERY MERGE (o)-[:CONTAINS]->(ub)"
        CYPHER_QUERY="$CYPHER_QUERY MERGE (p)-[:CONTAINS]->(ub)"
        CYPHER_QUERY="$CYPHER_QUERY MERGE (p)-[:CONTAINS]->(b);"
    done
    CYPHER_QUERY="$CYPHER_QUERY COMMIT;"

    echo $CYPHER_QUERY | docker exec -i "$MEMGRAPH_CONTAINER" mgconsole --host localhost --port 7687 >>"$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to insert objects for PG $PG_ID. Check $LOG_FILE" | tee -a "$LOG_FILE"
    else
        echo "Inserted $object_count objects for PG $PG_ID" | tee -a "$LOG_FILE"
    fi
}

# Export the function for GNU parallel
export -f process_pg_objects
export NAMESPACE OSD_POD DATA_PATH OSD_ID MEMGRAPH_CONTAINER TEMP_CYPHER_DIR LOG_FILE

echo "$pg_object_pairs" | parallel -j 1 --colsep '\t' process_pg_objects

# Force snapshot to ensure persistence
echo "Forcing snapshot..." | tee -a "$LOG_FILE"
echo "CALL mg.create_snapshot();" > "$TEMP_CYPHER_DIR/snapshot.cypher"
docker exec -i "$MEMGRAPH_CONTAINER" mgconsole --host localhost --port 7687 < "$TEMP_CYPHER_DIR/snapshot.cypher" >>"$LOG_FILE" 2>&1

# Clean up
rm -rf "$TEMP_CYPHER_DIR"

echo "Processing complete for OSD pod $OSD_POD. Logs in $LOG_FILE" | tee -a "$LOG_FILE"