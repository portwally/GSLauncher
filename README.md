# GSLauncher

A program launcher for the Apple IIgs (GS/OS, System 6). It shows one window with your applications in a row. Each one has its Finder icon, its name and the date of the file. Click one and it starts. When you quit that app, you come back to GSLauncher.

![GSLauncher](docs/launcher.png)

## Using it

- **Start it with the computer:** open the Control Panel's **Set Start**, choose *Select Application* and pick GSLauncher. GS/OS then starts GSLauncher instead of the Finder. **File > Quit to Finder** (Apple-Q) takes you to the Finder.
- **Add App…** (Apple-N): pick an application in the Standard File dialog. It can be an S16 file or a ProDOS 8 SYS file. There's room for 18 apps, five to a row.
- **Edit Slots** (Apple-E): while it is checked, a click picks a slot (a frame goes round it) instead of starting it. The arrow keys pick the next slot, and Escape leaves Edit mode. With a slot picked, you can use:
  - **Change Slot…**: choose another app for the slot.
  - **Rename Slot…** (Apple-R): change the name under the icon. Leave it empty to use the file's name again.
  - **Remove Slot**
  - **Move Left / Move Right**
- **Icons:** each app's icon comes from the Finder's icon files ($CA). GSLauncher looks first in an `Icons` folder next to the app, then in the `Icons` folder at the top of its disk. It matches the file type and the file name, and `=` in a name works as a wildcard. An app without an icon gets a plain one. If a slot's file is missing, its icon is dimmed and "not found" appears under it.
- **Date:** the date under the name is when the file last changed (`04 Nov 11:58`), which shows you that a new build has arrived.

The slots are kept in `Launcher.Slots`, a text file in GSLauncher's folder. Each line is one slot, written `name=path`. A `*` at the start of a path stands for the boot disk. GSLauncher rewrites the file whenever you change the slots, and you can also edit it by hand:

```
GS Commander=*:GSCommander:GSCommander
MegaconvertGS=*:MegaconvertGS:MegaconvertGS
Conquer GS=*:ConquerGS2:CONQUER.SYSTEM
```

### How it launches

GSLauncher uses GS/OS `Quit` with the app's full path and the return flag ($8000), so GS/OS starts GSLauncher again when the app quits. That works for ProDOS 8 apps too. Before quitting, GSLauncher:

- expands a leading `*` to the boot disk's name;
- sets prefix 0 (ProDOS 8's prefix) to the app's folder, so a P8 app finds the files next to it.

## Copying new builds to the disk you boot: `install.sh`

```bash
./install.sh                 # all of them
./install.sh gscommander     # or some: launcher, gscommander, megaconvert, conquer
```

`install.sh` copies each app's latest build into its folder on `~/Roms/apple2gs/My GS Apps.hdv`, which you can change with `DISK=...`. It takes the builds from the projects in `~/Documents`, so run each project's `./build.sh` first. Each run:

- replaces the app's old files and leaves its other files (settings, saved games) alone;
- puts its Finder icon in the app folder's `Icons` folder;
- writes `Launcher.Slots` only the first time;
- keeps a copy of the disk image as it was (`.bak`);
- refuses to run while MAME is running (`FORCE=1` overrides that).

| App | Folder on the disk | From |
| --- | --- | --- |
| GSLauncher | `GSLauncher` | `build/GSLauncher` |
| GS Commander | `GSCommander` | `GS Commander/build/GSCmdr` |
| MegaconvertGS | `MegaconvertGS` | `MegaconvertGS/build/MegaconvertGS` |
| Conquer GS 2 | `ConquerGS2` | `Conquer GS 2/build/*` |

## Building

```bash
./build.sh        # build/GSLauncher (Merlin 32; MERLIN32=... for its path)
./make_disk.sh    # build/GSLauncher.po: an 800K disk with it, its read-me and icon
```

`build.sh` also runs `art/make_icon.py`. That script writes the Finder icon file (`build/GSL.Icons`) and the generic icon (`src/genicon.s`). If Merlin reports "Bad Jump", run `test/fixbranches.sh`.

## Testing in MAME

```bash
test/run.sh
```

`test/run.sh` boots a copy of `My GS Apps.hdv` in Ample's MAME. It installs everything with `install.sh` and puts GSLauncher in the Finder's place, so it starts at boot. Options:

- `KEYS` and `SHOTS` press keys, move and click the mouse, and save screens. They work the same as in GS Commander's harness (see `test/dump.lua`).
- `SLOTS=file` uses another slots file, and `SLOTS=none` starts with no slots.

The screens end up in `build/test/screens/*.png`. For example, this launches GS Commander, quits it with its `0` key, and shows the launcher again:

```bash
RUN_SECONDS=85 KEYS="28:mouse-198-62,31:click,58:0" SHOTS="45:b,80:d" test/run.sh
```

Things the MAME tests have shown working: launching S16 and ProDOS 8 apps and returning from them, Edit mode, Rename, Move, Remove, Add App through Standard File, the slots file being saved, missing apps, and a second row.

2026 Walter Tengler.
