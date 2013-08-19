#!/bin/bash

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/sharedrop
DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/sharedrop
LOGFILE=${LOGFILE:-$HOME/}
CONFIG_FILE="$CONFIG_DIR/config.sh"

log() {
  echo "`date +%FT%T` $@"
}

die () {
  log "Stopping ShareDrop"
  exit 1
}

notify () {
  notify-send --icon network_fs ShareDrop "$@"
}

error () {
  message="Error: $@"

  log "$message"
  notify "$message"

  die
}

sync () {
  rsync -e ssh -Lavz --chmod=ug=rX,o=rX --delete-after "$DATA_DIR/files/" "$REMOTE" 2>&1 |
    while read line; do
      log "rsync: $line"
    done
}

make_hash () {
  local file="$1"

  sha1sum "$file" | cut -d' ' -f1 | ruby -ne 'puts $_.to_i(16).to_s(36)'
}

# Redirect all output to the log
exec 2>&1 >>"$DATA_DIR/sharedrop.log"

trap die INT
trap sync USR1

log "Starting Sharedrop ($CONFIG_DIR, $DATA_DIR)"

if [ ! -d $CONFIG_DIR ]; then
  log "Creating config dir ($CONFIG_DIR)"
  mkdir -p $CONFIG_DIR
fi
if [ ! -d $DATA_DIR ]; then
  log "Creating data dir ($DATA_DIR)"
  mkdir -p $DATA_DIR/files/ # Also automatically create the files folder
fi

# Setup
REQUIREMENTS="inotifywait notify-send sha1sum rsync"
for bin in $REQUIREMENTS; do
  type $bin >/dev/null 2>&1 || (
    error "Missing executable: $bin"
    die
  )
done

source "$CONFIG_FILE" 2>/dev/null

if [ "$?" -ne 0 ]; then
  error "No config file found, create one at $CONFIG_FILE"
fi

if [ "x$REMOTE" = "x" ]; then
  error "No remote defined. Define REMOTE=<...> in $CONFIG_FILE"
else
  REMOTE="${REMOTE%/}"
fi

if [ "x$BASE_URL" = "x" ]; then
  error "No base url defined. Define BASE_URL=<...> in $CONFIG_FILE"
else
  BASE_URL="${BASE_URL%/}"
fi

# Start
INBOX="${1:-`pwd`}"
sync

inotifywait -qm "$INBOX" -e CLOSE_WRITE --format "%f" | while read infile; do
  ext="${infile##*.}"
  hash=$(make_hash "$INBOX/$infile")

  if expr index "$infile" "." >/dev/null; then
    outfile="$hash.$ext"
  else
    outfile="$hash"
  fi

  ln -s "$INBOX/$infile" "$DATA_DIR/files/$outfile"
  log "$infile -> $REMOTE/$outfile"
  sync
  notify "$BASE_URL/$outfile"
done
