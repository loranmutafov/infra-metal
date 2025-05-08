#!/bin/sh

function cmdexists {
  command -v "$1" > /dev/null 2>&1
}

function kubectl_cmd {
  if ! command -v kubectl > /dev/null 2>&1; then
    return 1
  fi

  return 0
}

function kubectl_rook_ceph_plugin_installed {
  if ! kubectl rook-ceph > /dev/null 2>&1; then
    return 1
  fi

  return 0
}

function rook_ceph_cluster_exists {
  if [ $(kubectl get cephcluster -n rook-ceph --no-headers 2>/dev/null | wc -l) -le 0 ]; then
    return 1
  fi

  return 0
}