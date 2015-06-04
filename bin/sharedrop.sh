#!/bin/bash

BIN_DIR=$(dirname $(realpath ${BASH_SOURCE}))
LIB_DIR=$(realpath "${BIN_DIR}/../lib")

source "${LIB_DIR}/core.sh"

log_and_notify "Starting Sharedrop ($CONFIG_DIR, $DATA_DIR)"

if [ ! -d "$CONFIG_DIR" ]; then
  log "Creating config dir ($CONFIG_DIR)"
  mkdir -p "$CONFIG_DIR"
fi

if [ ! -d "$DATA_DIR/files/thumbs" ]; then
  log "Creating data dir tree ($DATA_DIR)"
  # Also automatically creates the files and thumbs folder
  mkdir -p "$DATA_DIR/files/thumbs"
fi

if [ ! -f "$CONFIG_FILE" ]; then
  error "No config file found, create one at $CONFIG_FILE"
fi

if [ -z "$REMOTE" ]; then
  error "No remote defined. Define REMOTE=<...> in $CONFIG_FILE"
else
  REMOTE="${REMOTE%/}"
fi

if [ -z "$BASE_URL" ]; then
  error "No base url defined. Define BASE_URL=<...> in $CONFIG_FILE"
else
  BASE_URL="${BASE_URL%/}"
fi

# Start
if [[ $OS == "osx" ]]; then
  INBOX="${1:-$(pwd)}"
else
  INBOX="$(realpath "${1:-$(pwd)}")"
fi
sync

log "Watching $INBOX"

fswatch -0 "$INBOX" | while read -d "" infile; do
  if [ -f "$infile" ]; then
    ext="${infile##*.}"
    hash=$(make_hash "$infile")

    if echo "$infile" | grep -q "." >/dev/null; then
      outfile="$hash.$ext"
    else
      outfile="$hash"
    fi

    # Not sure why I get permission issue
    # ln -sf "$infile" "$DATA_DIR/files/$outfile"
    cp "$infile" "$DATA_DIR/files/$outfile"
    log "$infile -> $REMOTE/$outfile"
    sync
    notify "$BASE_URL/$outfile" "$BASE_URL/$outfile"

    # paste in clipboard
    if [[ $OS == "osx" ]]; then
      echo "$BASE_URL/$outfile" | pbcopy
    fi
  fi
done
