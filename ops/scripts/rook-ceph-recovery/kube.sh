#!/bin/sh

function kube_cp_pv_fifo {
  local namespace="$1"
  local pod="$2"
  local remote_path="$3"
  local local_path="$4"
  local known_size_bytes="$5"
  local log_file="$6"

  local fifo
  fifo=$(mktemp -u)
  mkfifo "$fifo"

  pv -s "$known_size_bytes" < "$fifo" > "$local_path" &
  local pv_pid=$!

  if ! kubectl cp -n "$namespace" "$pod:$remote_path" "$fifo" --retries 10 &> "$log_file"; then
    kill "$pv_pid"
    rm -f "$fifo"

    return 1
  fi

  # Explicitly close the FIFO to ensure pv finishes
  exec 3>"$fifo"
  exec 3>&-

  wait "$pv_pid" || true
  rm -f "$fifo"
}

function kube_cp_pv {
  local namespace="$1"
  local pod="$2"
  local remote_path="$3"
  local local_path="$4"
  local known_size="$5"
  local log_file="$6"

  pv -s "$known_size" < "$local_path" > /dev/null &
  local pv_pid=$!

  kubectl cp -n "$namespace" "$pod:$remote_path" "$local_path" --retries 10 &> "$log_file"
  local status=$?

  wait "$pv_pid" 2>/dev/null || true
  return "$status"
}