#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GIT_CMD="git -C "$SCRIPT_DIR""

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  init              Clone and initialize all submodules
  update            Update all submodules to their recorded commits
  checkout <name>   Checkout a specific submodule
  status            Show status of all submodules
  foreach <cmd>     Run <cmd> in each submodule
  info              Show info of all submodules
  help              Show this help message

Examples:
  $(basename "$0") init
  $(basename "$0") update
  $(basename "$0") checkout transcode-scripts
  $(basename "$0") foreach "git log -1 --oneline"
  $(basename "$0") info
EOF
}

cmd_init() {
    $GIT_CMD submodule update --init --recursive
}

cmd_update() {
    $GIT_CMD submodule update --recursive
}

cmd_checkout() {
    local name="$1"
    local path
    path=$($GIT_CMD config --get submodule."$name".path 2>/dev/null) || {
        echo "Error: submodule '$name' not found" >&2
        exit 1
    }
    $GIT_CMD -C "$path" checkout "$2" 2>/dev/null || $GIT_CMD -C "$path" checkout main 2>/dev/null || $GIT_CMD -C "$path" checkout master
    echo "Checked out in $path"
}

cmd_status() {
    $GIT_CMD submodule status
}

cmd_foreach() {
    local cmd="$*"
    $GIT_CMD submodule foreach "$cmd"
}

cmd_info() {
    echo "Submodules:"
    echo "---"
    mapfile -t module_names < <(grep -oP '^\[submodule "\K[^"]+' "$SCRIPT_DIR/.gitmodules")
    for name in "${module_names[@]}"; do
        local path url branch
        path=$(grep -A1 "^\[submodule \"$name\"" "$SCRIPT_DIR/.gitmodules" | grep path | awk -F'= ' '{print $2}')
        url=$($GIT_CMD config --get submodule."$name".url)
        branch=$($GIT_CMD -C "$path" branch --show-current 2>/dev/null || echo "(detached)")
        echo "  $name"
        echo "    path:   $path"
        echo "    url:    $url"
        echo "    branch: $branch"
        echo "    commit: $($GIT_CMD -C "$path" rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
        echo ""
    done
}

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

command="$1"
shift

case "$command" in
    init)     cmd_init ;;
    update)   cmd_update ;;
    checkout) [[ $# -lt 1 ]] && { echo "Error: submodule name required" >&2; exit 1; }; cmd_checkout "$@" ;;
    status)   cmd_status ;;
    foreach)  [[ $# -lt 1 ]] && { echo "Error: command required" >&2; exit 1; }; cmd_foreach "$@" ;;
    info)     cmd_info ;;
    help|--help|-h) usage ;;
    *)        echo "Unknown command: $command" >&2; usage; exit 1 ;;
esac
