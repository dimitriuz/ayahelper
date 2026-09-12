# Changelog

All notable changes to ayaHelper are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[semantic versioning](https://semver.org/) — while the major version is 0, a
minor bump may change behaviour.

## [Unreleased]

## [0.1.0] — 2026-09-12

First release. Developed and tested on one machine: an AYANEO SLIDE (board
`AS01`, EC `0x001b0100`) on CachyOS with KDE Plasma on Wayland. Read the safety
notes in the README before installing.

### Added

- **Controller** — stick deadzone and per-stick sensitivity, rumble strength,
  swap ABXY, trigger and gyro levels, per-button turbo, factory reset. Driven
  over the GuLiKit MCU's UART at I/O `0x3E8`, 115200 8N1.
- **Lighting** — keyboard backlight colour, effect, brightness and Fn light via
  HID feature report `0x41`; joystick ring colour, brightness, and Breathe and
  Rainbow effects animated by the app.
- **Power** — ACPI platform profile, sustained TDP through `ryzenadj`, and a
  charge limit and bypass switch.
- **Fan** — automatic, a fixed speed, or a temperature curve you drag, with
  three independent guards against holding a speed that overheats the machine.
- **Sensors** — temperatures, APU package power and battery state.
- **Input** — InputPlumber profile switching, binding for the handheld's extra
  buttons, pointer speed and deadzone, emulated controller selection and
  service control.
- `--map` to bind a handheld button from a script, `--status` to print device
  and settings state without writing anything, and `--fan-auto` as a failsafe
  that hands the fan back to the EC.
- A tray icon, and a handheld button that opens the window — so the app is
  reachable with no pointer attached.

### Known not to work on this hardware

Implemented, measured, and reported honestly in the UI rather than left to look
like it works:

- **Charge limit and bypass.** The write reaches EC `0xd1d1` and the battery
  charges straight through it. AYASpace's own charge settings do nothing on this
  unit either, on Windows. The app measures this and reports `honoured=no`.
- **Radar and Ripple ring effects.** The driver exposes one colour for both
  rings with no way to address a quadrant.
- **Reading TDP back** without the `ryzen_smu` module — `CONFIG_STRICT_DEVMEM`
  blocks `ryzenadj`'s metrics table, so the page shows measured APU power and
  says why.
