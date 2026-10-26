#!/bin/sh
# Installs the company's standard Mac apps (Fleet Free has no software installer feature, so this
# script does it). Apps already in place are skipped, so it's safe to re-run on any Mac.
#
# Edit APPS to change the standard set. One app per line:
#   <path the app installs to>|<direct download URL of a .pkg, .dmg or .zip>
set -u

APPS='
/Applications/Google Chrome.app|https://dl.google.com/chrome/mac/universal/stable/gcem/GoogleChrome.pkg
/Applications/Slack.app|https://slack.com/ssb/download-osx-universal
'

WORK=$(mktemp -d /tmp/rar-apps.XXXXXX)
trap 'hdiutil detach -quiet "$WORK/mnt" 2>/dev/null; rm -rf "$WORK"' EXIT

copy_app_from() {
  src_app=$(find "$1" -maxdepth 2 -name '*.app' -type d | head -n 1)
  [ -n "$src_app" ] || return 1
  ditto "$src_app" "/Applications/$(basename "$src_app")"
}

install_from_dmg() {
  mkdir -p "$WORK/mnt"
  hdiutil attach -nobrowse -readonly -noverify -quiet -mountpoint "$WORK/mnt" "$1" || return 1
  pkg=$(find "$WORK/mnt" -maxdepth 1 -name '*.pkg' | head -n 1)
  if [ -n "$pkg" ]; then
    installer -pkg "$pkg" -target / >/dev/null
  else
    copy_app_from "$WORK/mnt"
  fi
  status=$?
  hdiutil detach -quiet "$WORK/mnt"
  return $status
}

install_one() {
  file="$WORK/download"
  rm -rf "$file" "$WORK/unzipped"
  curl -fsSL --retry 3 -o "$file" "$1" || return 1
  case "$(head -c 4 "$file")" in
    'xar!') installer -pkg "$file" -target / >/dev/null ;;
    PK*) ditto -x -k "$file" "$WORK/unzipped" && copy_app_from "$WORK/unzipped" ;;
    *) install_from_dmg "$file" ;;
  esac
}

failed=0
OLD_IFS=$IFS
IFS='
'
for line in $APPS; do
  app=${line%%|*}
  url=${line#*|}
  if [ -d "$app" ]; then
    echo "OK      $app (already installed)"
    continue
  fi
  if install_one "$url" && [ -d "$app" ]; then
    echo "INSTALL $app"
  else
    echo "FAILED  $app from $url" >&2
    failed=1
  fi
done
IFS=$OLD_IFS

exit $failed
