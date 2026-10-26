#!/bin/sh
# Makes every local user a standard user except itadmin. Refuses to run unless itadmin exists and
# is an admin, so a Mac is never left without an administrator. Log in as itadmin once before
# running this to confirm the password works.
set -eu

KEEP_ADMIN=itadmin

is_admin() {
  dsmemberutil checkmembership -U "$1" -G admin 2>/dev/null | grep -q "is a member"
}

if ! is_admin "$KEEP_ADMIN"; then
  echo "Refusing: $KEEP_ADMIN is missing or not an admin. Run create-it-admin.sh first." >&2
  exit 1
fi

changed=0
for user in $(dscl . -list /Users UniqueID | awk '$2 >= 501 { print $1 }'); do
  [ "$user" = "$KEEP_ADMIN" ] && continue
  if is_admin "$user"; then
    dseditgroup -o edit -d "$user" -t user admin
    echo "Removed admin rights from $user"
    changed=1
  fi
done

[ "$changed" -eq 0 ] && echo "No other admin accounts found."
exit 0
