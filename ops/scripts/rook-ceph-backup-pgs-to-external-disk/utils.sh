#!/bin/sh

function jqupdate {
  local file="$1"
  local key="$2"
  local value="$3"

  # Update the JSON file using jq
  jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$file" > tmp.$$.json && mv tmp.$$.json "$file"
}

function jqinplace {
  local query="$1"
  local file="$2"

  # Update the JSON file using jq
  jq "$query" "$file" > tmp.$$.json && mv tmp.$$.json "$file"
}