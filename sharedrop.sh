#!/bin/bash

debug () {
  if [ "x$DEBUG" != "x" ]; then
    echo "Debug: $@" >&2
  fi
}

notify () {
  notify-send --icon network_fs ShareDrop "$@"
}

error () {
  message="Error: $@"
  echo "$message" >&2
  notify "$message"

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

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/sharedrop
CONFIG_FILE="$CONFIG_DIR/config.sh"

source "$CONFIG_FILE" 2>/dev/null
if [ "$?" -ne 0 ]; then
  error "No config file found, create one at $CONFIG_FILE"
fi

if [ "x$REMOTE" = "$x" ]; then
  error "No remote defined. Define REMOTE=<...> in $CONFIG_FILE"
else
  REMOTE="${REMOTE%/}"
fi

if [ "x$BASE_URL" = "$x" ]; then
  error "No base url defined. Define BASE_URL=<...> in $CONFIG_FILE"
else
  BASE_URL="${BASE_URL%/}"
fi

# Start
INBOX="${1:-`pwd`}"

inotifywait -qm "$INBOX" -e CLOSE_WRITE --format "%f" | while read infile; do
  ext="${infile##*.}"
  hash=$(sha1sum "$INBOX/$infile" | cut -d' ' -f1)

  ext="${infile##*.}"
  if expr index "$infile" "." >/dev/null; then
    outfile="$hash.$ext"
  else
    outfile="$hash"
  fi

  scp "$INBOX/$infile" "$REMOTE/$outfile"
  debug "$infile -> $REMOTE/$outfile"
  notify "$BASE_URL/$outfile"
done
