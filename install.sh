#!/usr/bin/env bash
# Install ayaHelper. Run from a release tarball or a source checkout.
#
# Refuses to guess: if the binary is not next to this script and not already
# built, it says what to run rather than building something unexpected.
set -euo pipefail

BIN=""
for candidate in ./ayahelper ./target/release/ayahelper; do
    [ -x "$candidate" ] && { BIN="$candidate"; break; }
done
if [ -z "$BIN" ]; then
    echo "No ayahelper binary found. Build it first:" >&2
    echo "    cargo build --release" >&2
    exit 1
fi
[ -d rootfs ] || { echo "rootfs/ not found - run this from the tarball or checkout root" >&2; exit 1; }

echo "Installing $BIN to /usr/bin/ayahelper"
sudo install -m755 "$BIN" /usr/bin/ayahelper
sudo cp -r rootfs/usr/. /usr/.
sudo udevadm control --reload
sudo udevadm trigger

echo "Enabling services"
sudo systemctl daemon-reload
sudo systemctl enable --now ayahelper-privileged.service
systemctl --user daemon-reload
systemctl --user enable --now ayahelper.service ayahelper-restore.service

cat <<'DONE'

Installed. Check it with:

    ayahelper --status

If a device shows as unavailable, the udev rules have not reached your running
session yet - log out and back in.
DONE
