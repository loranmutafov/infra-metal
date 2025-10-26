#!/bin/sh

function jqupdate {
  local file="$1"
  local key="$2"
  local value="$3"

  # Update the JSON file using jq
  jq -e --arg value "$value" ".\"${key}\" = $value" "$file" > tmp.$$.json && mv tmp.$$.json "$file"
}

function jqset {
  local content="$1"
  local key="$2"
  local value="$(echo "$3" | xargs)"

  echo $content | jq -e --arg value "$value" ".${key} = \$value"
}

function jqget {
  local content="$1"
  local key="$2"

  # Extract the value using jq
  echo "$content" | jq -r ".${key} // empty"
}

# bstat stands for backup-status
function bstat_set_status {
  local key="$1"
  local value="$(echo "$2" | xargs)"

  backup_json=$(jqset "$backup_json" "status.$key" "$value")
}

function bstat_get_status {
  local key="$1"

  # Extract the value using jq
  jqget "$backup_json" "status.$key"
}

function bstat_set_osd {
  local osd="$(echo "$1" | xargs)"
  local key="$2"
  local value="$(echo "$3" | xargs)"

  backup_json=$(jqset "$backup_json" "[\"osd-$osd\"].$key" "$value")
}

function bstat_get_osd {
  local osd="$(echo "$1" | xargs)"
  local key="$2"

  # Extract the value using jq
  jqget "$backup_json" "[\"osd-$osd\"].$key"
}

function bstat_set_pg {
  local osd="$(echo "$1" | xargs)"
  local pg="$(echo "$2" | xargs)"
  local key="$3"
  local value="$(echo "$4" | xargs)"

  bstat_set_osd "$osd" "pgs[\"$pg\"][\"$key\"]" "$value"
}

function bstat_get_pg {
  local osd="$(echo "$1" | xargs)"
  local pg="$(echo "$2" | xargs)"
  local key="$3"

  bstat_get_osd "$osd" "pgs[\"$pg\"][\"$key\"]" "$value"
}
