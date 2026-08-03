#!/bin/sh
# =====================================================================
#  install.sh - install the `sandboxed` shell function into your shell rc.
#
#  The function points at the ai-sandbox.sb that lives in THIS repo, so nothing
#  needs to be copied to ~. Re-run any time; it refreshes the block in place.
#
#    ./install.sh            install (or refresh) the `sandboxed` function
#    ./install.sh --remove   uninstall the function
#
#  After install, start a new shell (or `source ~/.zshrc`), then:
#    cd ~/your/project && sandboxed claude
# =====================================================================
set -eu

# --- resolve the repo dir (where this script + ai-sandbox.sb live) ---
self=$0
while [ -L "$self" ]; do
  dir=$(CDPATH= cd -P -- "$(dirname -- "$self")" && pwd)
  self=$(readlink -- "$self")
  case "$self" in
    /*) : ;;
    *) self="$dir/$self" ;;
  esac
done
REPO_DIR=$(CDPATH= cd -P -- "$(dirname -- "$self")" && pwd)
SB="$REPO_DIR/ai-sandbox.sb"

if [ ! -f "$SB" ]; then
  printf 'ERROR: ai-sandbox.sb not found at: %s\n' "$SB" >&2
  printf '       Run this script from inside the cloned ai-sandbox repo.\n' >&2
  exit 1
fi

# --- pick the shell rc file ---
case "${SHELL:-}" in
  *zsh)  RC="$HOME/.zshrc" ;;
  *bash) RC="$HOME/.bashrc" ;;
  *)
    if [ -f "$HOME/.zshrc" ]; then RC="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then RC="$HOME/.bashrc"
    else RC="$HOME/.zshrc"; fi ;;
esac

MARK_BEGIN="# >>> ai-sandbox >>>"
MARK_END="# <<< ai-sandbox <<<"

# --- --remove: strip the block and exit ---
if [ "${1:-}" = "--remove" ]; then
  if grep -q -- "$MARK_BEGIN" "$RC" 2>/dev/null && grep -q -- "$MARK_END" "$RC" 2>/dev/null; then
    awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
      $0==b {skip=1; next}
      $0==e {skip=0; next}
      !skip
    ' "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
    printf 'Removed the ai-sandbox block from %s\n' "$RC"
  else
    printf 'No ai-sandbox block found in %s\n' "$RC"
  fi
  exit 0
fi

# --- the function (SB path baked in; $HOME/$PWD/$@ expand at call time) ---
func="sandboxed() {
  sandbox-exec -f \"$SB\" \\
    -D HOME=\"\$HOME\" -D WORKSPACE=\"\$PWD\" \"\$@\"
}"

block="$MARK_BEGIN
# Installed by $REPO_DIR/install.sh  (run this script with --remove to uninstall)
$func
$MARK_END"

# --- ensure rc exists, then replace any existing block (or append fresh) ---
touch "$RC"
if grep -q -- "$MARK_BEGIN" "$RC" 2>/dev/null && grep -q -- "$MARK_END" "$RC" 2>/dev/null; then
  awk -v b="$MARK_BEGIN" -v e="$MARK_END" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    !skip
  ' "$RC" > "$RC.tmp" && mv "$RC.tmp" "$RC"
fi
printf '\n%s\n' "$block" >> "$RC"

printf 'Installed the `sandboxed` function into: %s\n' "$RC"
printf '  profile: %s\n' "$SB"
printf '\nRestart your shell (or: source "%s"), then:\n  cd ~/your/project && sandboxed claude\n' "$RC"
