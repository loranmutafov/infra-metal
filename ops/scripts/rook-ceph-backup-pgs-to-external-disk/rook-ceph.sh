function ceph_get_osds {
  osds_found=$(kubectl rook-ceph ceph osd ls 2>/dev/null)

  echo "$osds_found"
}

function get_osd_deployments {
  local osd_id="$1"

  osd_deployments=$(kubectl get deploy -n rook-ceph -l app=rook-ceph-osd -l osd=$osd_id --no-headers -o custom-columns=":metadata.name,:status.availableReplicas")

  echo "$osd_deployments"
}

function get_osd_maintenance_pod_name {
  local osd_id="$1"

  # Get the OSD maintenance pod name
  osd_maintenance_pod_name=$(kubectl get pod -n rook-ceph -l app=rook-ceph-osd -l osd=$osd_id --no-headers -o custom-columns=":metadata.name" | grep "rook-ceph-osd-$osd_id-maintenance")

  echo "$osd_maintenance_pod_name"
}

# ❯ kubectl get deploy -n rook-ceph -l app=rook-ceph-osd --no-headers -o custom-columns=":metadata.name,:status.availableReplicas"
#   rook-ceph-osd-0               1
#   rook-ceph-osd-1               1
#   rook-ceph-osd-2               <none>
#   rook-ceph-osd-2-maintenance   1
#   rook-ceph-osd-3               1
#   rook-ceph-osd-4               <none>
#   rook-ceph-osd-4-maintenance   1
#   rook-ceph-osd-5               1
function is_osd_maintenance {
  local osd_id="$1"

  # Check if the OSD is in maintenance mode
  local osd_deployments=$(get_osd_deployments "$osd_id")

  # Extract the deployment name and available replicas
  local osd_maintenance=$(echo "$osd_deployments" | grep "rook-ceph-osd-$osd_id-maintenance ")

  if [[ -z "$osd_maintenance" ]]; then
    echo "no maintenance deployment found"
    return
  fi

  local osd_available_replicas=$(echo "$osd_deployments" | grep "rook-ceph-osd-$osd_id " | awk '{print $2}')
  local osd_maintenance_replicas=$(echo "$osd_maintenance" | awk '{print $2}')

  # Check if the OSD is in maintenance mode
  if [[ "$osd_maintenance_replicas" == "1" && "$osd_available_replicas" == "<none>" ]]; then
    echo "true"
  else
    echo "maintenance replicas not 1 ($osd_maintenance_replicas) or osd available replicas not <none> ($osd_available_replicas)"
  fi
}