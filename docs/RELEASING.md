# Releasing

Versions are `MAJOR.MINOR.PATCH`, tagged `vX.Y.Z`. While the major version is 0,
a minor bump may change behaviour — this is one tested machine's worth of
confidence, not a stable contract.

## Cutting a release

1. **Update the changelog.** Move `[Unreleased]` entries into a new version
   section with today's date. The release notes are generated from this section,
   so write it for someone who has not read the commits.

2. **Bump `Cargo.toml`,** and commit `Cargo.lock` with it:

   ```bash
   cargo build --release      # refreshes Cargo.lock
   git commit -am "Release v0.1.0"
   ```

3. **Tag and push:**

   ```bash
   git tag -a v0.1.0 -m "ayaHelper v0.1.0"
   git push origin main --follow-tags
   ```

4. **The Release workflow does the rest** — it refuses to run if the tag and
   `Cargo.toml` disagree, builds, packages `ayahelper-<version>-x86_64-linux.tar.gz`
   with the binary, `rootfs/`, `install.sh` and the docs, publishes a checksum
   alongside it, and writes the notes from the changelog section.

## What the tarball is, and is not

It is built on GitHub's Ubuntu runner, so the binary needs that glibc or newer.
That covers rolling distributions — which is what these handhelds run — but it is
not a portable binary, and it is not signed. Building from source is equally
supported and is the honest recommendation for anything that matters.

The tarball deliberately contains the whole `rootfs/` rather than only the
binary: the udev rules are what make the gamepad and keyboard backlight reachable
without root, and a binary on its own would appear half-broken.

## Checks before tagging

CI runs `cargo fmt --check`, `clippy -D warnings`, a release build and a smoke
test on every push, so a green `main` is the precondition. None of that touches
hardware — there is none on a runner — so anything that writes to a device still
has to be tried on the handheld first:

```bash
ayahelper --status        # writes nothing; the right first command
```
