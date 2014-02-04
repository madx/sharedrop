#!/bin/bash

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/sharedrop
DATA_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/sharedrop
LOGFILE=${LOGFILE:-$HOME/sharedrop.log}
CONFIG_FILE="$CONFIG_DIR/config.sh"
INDEX_FILE_NAME="list.html"

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

build_index () {
  INDEX_FILE="$DATA_DIR/files/$INDEX_FILE_NAME"

  echo -n > "$INDEX_FILE"

  ls -t1 "$DATA_DIR/files" | egrep -v "$INDEX_FILE_NAME|thumbs" | while read file; do
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

  rsync -e ssh -Lavz --chmod=u=rwX,g=rX,o=rX --delete-after "$DATA_DIR/files/" "$REMOTE" 2>&1 |
    while read line; do
      log "rsync: $line"
    done
}

make_hash () {
  local file="$1"

  sha1sum "$file" | cut -d' ' -f1 | ruby -ne 'puts $_.to_i(16).to_s(36)'
}

[ "$LOGFILE" = "-" ] && LOGFILE=/dev/stdout

# Redirect all output to the log
exec 2>&1 >>"$LOGFILE"

trap die INT
trap sync USR1

log "Starting Sharedrop ($CONFIG_DIR, $DATA_DIR)"

if [ ! -d $CONFIG_DIR ]; then
  log "Creating config dir ($CONFIG_DIR)"
  mkdir -p $CONFIG_DIR
fi
if [ ! -d $DATA_DIR ]; then
  log "Creating data dir ($DATA_DIR)"
  mkdir -p $DATA_DIR/files/thumbs # Also automatically create the files and thumbs folder
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
: ${INBOX:="$(realpath ${1:-`pwd`})"}
log "Inbox: $INBOX"
sync

inotifywait -qm "$INBOX" -e CLOSE_WRITE --format "%f" | while read infile; do
  ext="${infile##*.}"
  hash=$(make_hash "$INBOX/$infile")

  if expr index "$infile" "." >/dev/null; then
    outfile="$hash.$ext"
  else
    outfile="$hash"
  fi

  ln -sf "$INBOX/$infile" "$DATA_DIR/files/$outfile"
  log "$infile -> $REMOTE/$outfile"
  sync
  notify "<a href=\"$BASE_URL/$outfile\">$BASE_URL/$outfile</a>"
done
