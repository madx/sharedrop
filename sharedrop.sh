#!/bin/bash

debug () {
  if [ "x$DEBUG" != "x" ]; then
    echo "Debug: $@" >&2
  fi
}

error () {
  echo "Error: $@" >&2
  exit 1
}

# Setup
REQUIREMENTS="inotifywait notify-send sha1sum sshfs"
for bin in $REQUIREMENTS; do
  type $bin >/dev/null 2>&1 || (
    error "Missing executable: $bin"
    exit 1
  )
done

DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/sharedrop
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/sharedrop
OUTBOX="$DATA_DIR/outbox"
CONFIG_FILE="$CONFIG_DIR/config.sh"

if [ ! -d "$DATA_DIR" ]; then
  debug "Creating $DATA_DIR"
  mkdir -p "$DATA_DIR"
fi

if [ ! -d "$OUTBOX" ]; then
  debug "Creating $OUTBOX"
  mkdir -p "$OUTBOX"
fi

source "$CONFIG_FILE" 2>/dev/null
if [ "$?" -ne 0 ]; then
  error "No config file found, create one at $CONFIG_FILE"
fi

if [ "x$REMOTE" = "$x" ]; then
  error "No remote defined. Define REMOTE=<...> in $CONFIG_FILE"
fi

if [ "x$BASE_URL" = "$x" ]; then
  error "No base url defined. Define BASE_URL=<...> in $CONFIG_FILE"
fi

# Start
INBOX="${1:-`pwd`}"

debug "Mounting $REMOTE to $OUTBOX"
sshfs "$REMOTE" "$OUTBOX"

teardown () {
  fusermount -u "$OUTBOX"
}

trap teardown INT

inotifywait -qm "$INBOX" -e CLOSE_WRITE --format "%f" | while read infile; do
  ext="${infile##*.}"
  hash=$(sha1sum "$INBOX/$infile" | cut -d' ' -f1)

  ext="${infile##*.}"
  if expr index "$infile" "." >/dev/null; then
    outfile="$hash.$ext"
  else
    outfile="$hash"
  fi

  cp "$INBOX/$infile" "$OUTBOX/$outfile"
  debug "$infile -> $outfile"
  notify-send --icon network_fs ShareDrop "$BASE_URL/$outfile"
done
