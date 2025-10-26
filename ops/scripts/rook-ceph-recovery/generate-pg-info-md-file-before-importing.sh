#!/bin/bash

set -e

# Usage function
usage() {
    echo "Usage: $0 -o OSD_ID -p PG_ID1[,PG_ID2,...] [-n NAMESPACE] [-f OUTPUT_FILE]"
    echo "  -o OSD_ID        OSD ID (e.g., 0)"
    echo "  -p PG_IDS        Comma-separated list of PG IDs (e.g., 1.0,1.1,1.2)"
    echo "  -n NAMESPACE     Kubernetes namespace (default: rook-ceph)"
    echo "  -f OUTPUT_FILE   Output markdown file (default: pg_info_TIMESTAMP.md)"
    exit 1
}

# Parse arguments
OSD_ID=""
PG_IDS=""
NAMESPACE="rook-ceph"
OUTPUT_FILE=""

while getopts "o:p:n:f:h" opt; do
    case $opt in
        o) OSD_ID="$OPTARG" ;;
        p) PG_IDS="$OPTARG" ;;
        n) NAMESPACE="$OPTARG" ;;
        f) OUTPUT_FILE="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

# Validate required arguments
if [[ -z "$OSD_ID" || -z "$PG_IDS" ]]; then
    echo "Error: OSD ID and PG IDs are required"
    usage
fi

# Set default output file if not provided
if [[ -z "$OUTPUT_FILE" ]]; then
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    OUTPUT_FILE="pg_info_${TIMESTAMP}.md"
fi

echo "Collecting PG info for OSD $OSD_ID in namespace $NAMESPACE"
echo "PG IDs: $PG_IDS"
echo "Output file: $OUTPUT_FILE"

# Find the maintenance pod for the specified OSD
echo "Finding maintenance pod for OSD $OSD_ID..."
MAINTENANCE_POD=$(kubectl get pods -n "$NAMESPACE" -l "app=rook-ceph-osd,ceph_daemon_id=$OSD_ID" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [[ -z "$MAINTENANCE_POD" ]]; then
    echo "Error: Could not find maintenance pod for OSD $OSD_ID in namespace $NAMESPACE"
    echo "Make sure the OSD is in maintenance mode and the pod exists"
    exit 1
fi

echo "Found maintenance pod: $MAINTENANCE_POD"

# Initialize output file (empty)
> "$OUTPUT_FILE"

# Convert comma-separated PG IDs to array
IFS=',' read -ra PG_ARRAY <<< "$PG_IDS"

# Process each PG ID
for PGID in "${PG_ARRAY[@]}"; do
    # Trim whitespace
    PGID=$(echo "$PGID" | xargs)

    echo "Processing PG ID: $PGID"

    # Add PG section to markdown file using your exact format
    cat >> "$OUTPUT_FILE" << EOF
# $PGID - OSD $OSD_ID
## OSD $OSD_ID info before import

\`\`\`json
EOF

    # Get OSD info
    echo "  Collecting OSD info for PG $PGID..."

    if kubectl exec -n "$NAMESPACE" "$MAINTENANCE_POD" -- ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-$OSD_ID --pgid "$PGID" --op info 2>/dev/null >> "$OUTPUT_FILE"; then
        echo "  ✓ OSD info collected successfully"
    else
        echo "  ⚠ Warning: Failed to collect OSD info for PG $PGID"
        echo "Error: Failed to collect OSD info" >> "$OUTPUT_FILE"
    fi

    cat >> "$OUTPUT_FILE" << EOF
\`\`\`

## Cluster info before import

\`\`\`json
EOF

    # Get cluster info
    echo "  Collecting cluster info for PG $PGID..."

    if kubectl rook-ceph ceph pg "$PGID" query 2>/dev/null >> "$OUTPUT_FILE"; then
        echo "  ✓ Cluster info collected successfully"
    else
        echo "  ⚠ Warning: Failed to collect cluster info for PG $PGID"
        echo "Error: Failed to collect cluster info" >> "$OUTPUT_FILE"
    fi

    # Complete the template for this PG with your exact format
    cat >> "$OUTPUT_FILE" << EOF
\`\`\`

## Import output

\`\`\`bash

\`\`\`

## OSD $OSD_ID info after import

\`\`\`bash

\`\`\`

## Cluster info after import

\`\`\`bash

\`\`\`

EOF

    echo "  ✓ PG $PGID section completed"
done

echo
echo "✅ All PG info collected successfully!"
echo "Output written to: $OUTPUT_FILE"
echo
echo "Next steps:"
echo "1. Review the collected info in $OUTPUT_FILE"
echo "2. Perform your PG import operations"
echo "3. Fill in the remaining sections manually after import"