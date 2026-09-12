# Working on ayaHelper

Context that is expensive to rediscover. The README is for users; this is for
whoever is editing the code next.

## The target machine

One AYANEO SLIDE, and everything here is calibrated to it:

| | |
|---|---|
| Board / EC | `AS01` / `0x001b0100` |
| OS | CachyOS, `linux-cachyos-deckify`, KDE Plasma on Wayland |
| Reach it | `ssh dimitrius@192.168.1.31` (key is set up; passwordless sudo via `/etc/sudoers.d/nopasswd` — **leave that file alone**) |

Feature gates are on **`board_name`** (`AS01`), never `product_name` — that was a
real bug once.

## The dev loop

Build locally to check it compiles; build *on the device* to test it, because
nothing here can be exercised without the hardware.

```bash
cargo build --release                     # local: compile check
tar -cz --exclude=./target --exclude=./.git -f - . \
  | ssh dimitrius@192.168.1.31 'tar -xzf - -C ~/ayahelper'
ssh dimitrius@192.168.1.31 'cd ~/ayahelper && cargo build --release'
ssh dimitrius@192.168.1.31 'sudo install -m755 ~/ayahelper/target/release/ayahelper /usr/bin/ayahelper'
```

Then restart whatever you changed:

```
systemctl --user restart ayahelper.service        # tray  (user)
sudo systemctl restart ayahelper-privileged.service # fan, TDP, charge (system)
```

`ayahelper --status` writes nothing and is the right first command after any
change.

### The remote shell is fish

`ssh dimitrius@…` lands in **fish**, which breaks `$?`, `VAR=x cmd`, `for` loops
and most quoting. Write the script to a file in the scratchpad, `scp` it over,
and run it. Trying to inline a bash one-liner over ssh wastes turns.

Also: `pkill -f 'something'` over ssh **matches the ssh command's own cmdline**
and kills the session. Kill by PID.

## Architecture, and why

- **The tray and the window are separate processes.** `ViewportCommand::Visible(false)`
  is a no-op on Wayland — verified against KWin, which kept reporting
  `hidden=false visible=true` while the app believed it had hidden itself.
  Closing the window closes a process; the tray is untouched because it was
  never part of it.
- **`worker.rs` owns all device I/O.** Anything touching a device on the render
  thread makes the window go "(Not Responding)".
- **Ring effects are animated by whichever process holds an `flock`** on
  `$XDG_RUNTIME_DIR/ayahelper-rings.lock`. Both tray and window call
  `rings::run_effects()`; the lock decides which drives, and the survivor takes
  over when the other exits. The first version animated only in the tray, so
  quitting the tray silently froze the effect.
- **Only four things need root** (fan port I/O, `ryzenadj`, platform profile,
  charge limit) and they live behind a line protocol on
  `/run/ayahelper/privileged.sock`. Everything else runs as the user via udev
  `uaccess`. Keep it that way.
- **InputPlumber edits are live-only.** `set_mouse_speed`, `set_mouse_deadzone`
  and `set_button_action` rewrite the *running* profile; loading a profile
  discards them, so they are saved and re-applied in `Job::IpProfile`.
- **`SetTargetDevices` replaces the whole set** — pass `dbus` every time or the
  UI actions (`app`, `osk`) have nowhere to land.

## Testing on the device

Debug hooks (set them in the environment of `--window`):

| | |
|---|---|
| `AYAHELPER_TAB=input:1` | open straight onto a tab:subtab |
| `AYAHELPER_SELFTEST_CLOSE=n` | self-close after n seconds |
| `AYAHELPER_CUSTOM=1` | open the colour editor |
| `AYAHELPER_SCROLL_BOTTOM=1` | start scrolled to the bottom |

Screenshots: launch with those, wait ~5 s, then `spectacle -a -b -n -o /tmp/x.png`
(`-a` = active window). **Check whether the user is at the machine first** —
`-a` grabs whatever is focused, and `-f` grabs their whole desktop. Both have
captured the user's private windows in the past.

`--map <button> <action>` exercises the button binding without a GUI, and
`--status` covers device discovery.

## Things that are known not to work — do not re-investigate

Each cost real time to establish and is written up in the research repo:

- **Charge limit and bypass.** The write reaches EC `0xd1d1`; the battery charges
  straight through it. AYASpace's own charge settings do nothing on this unit
  either, on Windows. The app *measures* this and reports `honoured=no`.
- **Radar / Ripple ring effects.** `multi_index` is one `red green blue` triple
  for both rings — no per-quadrant addressing exists through the driver.
- **Reading TDP back** without the `ryzen_smu` module. `CONFIG_STRICT_DEVMEM`
  blocks `ryzenadj`'s metrics table; the page falls back to measured APU power
  and says why.

## Hazards

- **Never `modprobe -r ayaneo_platform`.** Its suspend, shutdown and remove paths
  all `kthread_stop()` the same pointers, so unloading double-stops and wedges
  the module (`refcount -1`, `charge_behaviour` disappears, no reload possible).
  Only a reboot clears it. Reboot to pick up a rebuilt module.
- **The fan's three guards are not optional** (85 °C → auto, 90 °C → latch,
  sensor lost → hand back). Holding a fan speed is the one thing here that can
  cook the machine.
- **Decky's PowerControl re-applies TDP every 15 s** and **hhd** resets it after
  every resume. `conflicts.rs` detects both and the UI says so; do not "fix" a
  TDP that will not stick without checking that warning first.
- **The gamepad MCU sleeps** across suspend and has no remote-wakeup bit. If
  `--status` says the controller is unavailable, press a button on the pad
  before debugging anything.

## Before pushing

CI gates on `cargo fmt --check` and `clippy --release --all-targets -D warnings`.
Run both; the clippy one catches real things (it found six `egui::Stroke::new`
float literals rustc is phasing out).

Releases: bump `Cargo.toml`, move the `[Unreleased]` changelog entries into a
version section, tag `vX.Y.Z`. The workflow **refuses to run if the tag and
`Cargo.toml` disagree**, builds the tarball with `rootfs/` and `install.sh`, and
takes the release notes from that changelog section. See `docs/RELEASING.md`.

Nothing in CI touches hardware — a green tick does not mean it works on the
handheld.

## Commit style

Explain *why*, and keep the negative results. A commit that says which theory
was wrong and what disproved it is worth more here than one describing the diff.
