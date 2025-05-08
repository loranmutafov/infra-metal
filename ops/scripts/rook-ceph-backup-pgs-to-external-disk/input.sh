#!/bin/sh

function read_input {
  local prompt="$1"
  local input

  read -r -p "$prompt: " input
  echo "$input"
}

function read_path_input {
  local prompt="$1"
  local input

  read -e -p "$prompt: " input
  realpath $(eval echo $input)
}

function prompt_continue {
  while true; do
    response=$(read_input "$1 [Y/n]")

    case $response in
      [Yy] ) return 0 ;;
      [Nn] ) return 1 ;;
      * )
        if [ -z "$response" ]; then
          return 0
        else
          echo "🤨 Please enter 'Y' or 'n'"
        fi
        ;;
    esac
  done
}

function choose_option {
  local prompt="$1"
  local options_str="$2"
  local option_prefix="$3"

  PS3="$prompt: "
  IFS=',' read -r -a options <<< "$options_str"

  local prefixed_options=()
  for opt in "${options[@]}"; do
    prefixed_options+=("$option_prefix$opt")  # Prefix each option
  done

  select opt in "${prefixed_options[@]}"; do
    if [[ " ${prefixed_options[@]} " =~ " $opt " ]]; then
      local unprefixed_opt="${opt#$option_prefix}"  # Remove prefix (e.g., 'osd-4' -> '4')
      echo "$unprefixed_opt" # Return the non-prefixed option (e.g., '4')
      break
    else
      echo "Invalid option. Please try again."
    fi
  done
}

function newlines_to_commas {
  local input=$(cat)
  echo "$input" | tr '\n' ',' | sed 's/,$//'
}
