#!/bin/bash

OS=unix
if [[ $(uname) = "Darwin" ]]; then
  OS=osx
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sharedrop"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/sharedrop"
LOGFILE="${LOGFILE:-$HOME/}"
CONFIG_FILE="$CONFIG_DIR/config.sh"
INDEX_FILE_NAME="${INDEX_FILE_NAME:-list.html}"
METHOD="${METHOD:-rsync}"

mkdir -p "$CONFIG_DIR"
mkdir -p "$DATA_DIR"

if [[ $OS == "osx" ]]; then
  NOTIFIER="${NOTIFIER:-"notify_osx"}"
  HASH_CMD=shasum
else
  NOTIFIER="${NOTIFIER:-"notify-send --icon network_fs ShareDrop"}"
  HASH_CMD=sha1sum
fi

notify_osx () {
  if type terminal-notifier > /dev/null; then
    terminal-notifier \
      -sound Pop \
      -appIcon "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/iDiskGenericIcon.icns" \
      -title "ShareDrop" \
      -message "$1" \
      -open "$2" \
      &> /dev/null
  # audio fallback :)
  elif type say > /dev/null; then
    say "ShareDrop message: $1"
  else
    echo "$1"
  fi
}


log () {
  echo "[$(date +%FT%T)]" "$@"
}

die () {
  log "Stopping ShareDrop"
  exit 1
}

notify () {
  $NOTIFIER "$@"
}

log_and_notify () {
  log "$@"
  notify "$@"
}

error () {
  log_and_notify "Error: " "$@"

  die
}

build_index () {
  INDEX_FILE="$DATA_DIR/files/$INDEX_FILE_NAME"

  echo -n > "$INDEX_FILE"

  find "$DATA_DIR/files" -mindepth 1 -printf "%f\n" |  egrep -v "$INDEX_FILE_NAME|thumbs" || true | while read file; do
    ext="${file##*.}"

    case "$ext" in
      png|jpg|jpeg|gif)
        thumbfile="$DATA_DIR/files/thumbs/$file"

        if [ ! -f "$thumbfile" ]; then
          log "Generating thumbnail for $file"
          convert -resize 100x100 "$DATA_DIR/files/$file" "$thumbfile"
        fi

        thumb="<img src=\"thumbs/$file\" />"
        ;;
      *|'')
        thumbfile="$DATA_DIR/files/thumbs/$ext.png"

        if [ ! -f "$thumbfile" ]; then
          log "Generating thumbnail for $ext"
          convert -size 100x100 -gravity center -pointsize 32 "label:$ext" "$thumbfile"
        fi

        thumb="<img src=\"thumbs/$ext.png\" />"
        ;;
    esac

    echo "<a href=\"$file\">$thumb</a>" >> "$INDEX_FILE"
  done
}

sync () {
  log "Syncing"

  build_index

  sync_command
}

sync_command () {
  rsync -e ssh -Lavz --chmod=u=rwX,go=rX --delete-after "$DATA_DIR/files/" "$REMOTE" 2>&1 |
    while read line; do
      log "rsync: $line"
    done
}

make_hash () {
  local file="$1"

  $HASH_CMD "$file" | cut -d' ' -f1 | ruby -ne 'puts $_.to_i(16).to_s(36)'
}

# Redirect all output to the log
exec >>"$DATA_DIR/sharedrop.log" 2>&1

trap die INT
trap sync USR1

# Check requirements
if [[ $OS == "osx" ]]
then
  REQUIREMENTS=""
else
  REQUIREMENTS="notify-send"
fi
REQUIREMENTS="fswatch convert $REQUIREMENTS $HASH_CMD $METHOD"

for bin in $REQUIREMENTS; do
  type "$bin" >/dev/null 2>&1 || (
    error "Missing executable: $bin"
    die
  )
done

source "$CONFIG_FILE" 2>/dev/null
