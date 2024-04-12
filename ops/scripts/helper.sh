#!/usr/bin/env sh

is_macos() {
  [ "$(uname)" = "Darwin" ]
}

is_linux() {
  [ "$(uname)" = "Linux" ]
}

find_macos_app() {
  appname="$1.app"
  apppath=$(mdfind "kMDItemKind == 'Application' && kMDItemFSName == '$appname'c")
  if [ -d "$apppath" ]; then
    echo $apppath
    return 0
  else
    return 1
  fi
}

find_command() {
  command -v "$1" > /dev/null && echo $1
}

is_package_available() {
  if is_macos; then
    find_macos_app "$1" || find_command "$1"
  elif is_linux; then
    find_command "$1"
  else
    return 1
  fi
}

preflight_pkg() {
  if is_package_available "$1" > /dev/null; then
    echo "✅ $1 is installed"
  else
    echo "🔥 Error: $1 is not installed" 2>&1
    exit 1
  fi
}

preflight_os() {
  if is_macos; then
    echo "✅ MacOS detected"
  elif is_linux; then
    echo "✅ Linux detected"
  else
    echo "🔥 Error: Unsupported OS" 2>&1
    exit 1
  fi
}

tailscale_cmd() {
  if find_macos_app tailscale > /dev/null; then
    $(find_macos_app tailscale)/Contents/MacOS/Tailscale $1
  else
    $(find_command tailscale) $1
  fi
}

is_tailscale_connected() {
  tailscale_cmd status > /dev/null
}
