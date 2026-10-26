#!/bin/sh
# Creates the hidden local admin account "itadmin" that IT uses once staff accounts are standard
# users. Safe to re-run: an existing account is only re-added to the admin group.
#
# The account has no Secure Token (only an existing token holder can grant one), so it can't
# unlock FileVault or approve macOS updates on Apple silicon. It's for installs and settings.
set -eu

USERNAME=itadmin
PASSWORD='$FLEET_SECRET_MACOS_ITADMIN_PASSWORD'

case "$PASSWORD" in
  '$'*)
    echo "Fleet secret MACOS_ITADMIN_PASSWORD wasn't substituted; refusing to create the account." >&2
    exit 1
    ;;
esac

if id "$USERNAME" >/dev/null 2>&1; then
  dseditgroup -o edit -a "$USERNAME" -t user admin
  echo "$USERNAME already exists; made sure it is an admin."
  exit 0
fi

sysadminctl -addUser "$USERNAME" -fullName "IT Admin" -password "$PASSWORD" -admin
if ! id "$USERNAME" >/dev/null 2>&1; then
  echo "sysadminctl did not create $USERNAME." >&2
  exit 1
fi
dscl . -create "/Users/$USERNAME" IsHidden 1
echo "Created hidden admin account $USERNAME."
