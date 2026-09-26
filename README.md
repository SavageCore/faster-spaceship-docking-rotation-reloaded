# Faster Spaceship Docking Rotation Reloaded

Rebuild of the NMS 3.88-era  [Faster Spaceship Docking Rotation](https://www.nexusmods.com/nomanssky/mods/2250) mod for Cosmos as a FOMOD so you can pick between Instant and 10x speeds, built natively on Linux with the
[AMUMSS Linux port](https://github.com/SavageCore/AMUMSS/tree/feat/linux-support) (WIP! Good simple test case.).

## Usage

During installation, pick "Instant" or "10x" to set `DockingRotateSpeed`. The default value is 1.

| Variant | `DockingRotateSpeed` |
| --- | --- |
| Instant | 100
| 10x | 10 |

## Build (on Linux)

Requires a full AMUMSS install at `~/AMUMSS` (override with
`AMUMSS_HOME=...`) with `MBINCompiler-linux` fetched
(`linux/scripts/fetch_mbincompiler.sh` in the AMUMSS repo).

```sh
make release      # clean rebuild + verify + pack dist/ zip (default)
make release VERSION=0.1.0   # override version in zip name
make verify       # sanity-check the built outputs
make clean        # remove build/ and dist/
```

`make build` temporarily stages the two scripts into
`$(AMUMSS_HOME)/ModScript` (existing content moved aside and restored),
runs one `buildmod.sh --run-pipeline`, and collects the outputs.

## Release

`make release` creates `dist/Faster Spaceship Docking Rotation Reloaded <VERSION>.zip` which is the zip file to import into [Amethyst](https://github.com/ChrisDKN/Amethyst-Mod-Manager)/[Vortex](https://github.com/Nexus-Mods/Vortex) or upload to Nexus.

## Game updates / versioning

The mod version is `VERSION` in the Makefile.
The game version the scripts target is `GameVersion` in `src/docking.lua.in`.

When No Man's Sky updates:

1. Fetch the new matching compiler from the AMUMSS repo (use `MBINCOMPILER_TAG=vX` to pin):
   `AMUMSS_HOME=~/AMUMSS linux/scripts/fetch_mbincompiler.sh`
   If the AMUMSS core itself changed, re-run the pipeline once so the
   linux patches re-verify (`apply_linux_patches.sh --verify`).
2. Bump `GameVersion` in `src/docking.lua.in`.
3. Bump `VERSION` in the Makefile.
4. `make release`, `make verify`, import, deploy, test.
