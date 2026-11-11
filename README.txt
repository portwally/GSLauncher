GSLauncher 1.2
==============

A program launcher for the Apple IIgs (GS/OS, System 6). One window shows
your applications in a row, each with its Finder icon, its name and the date
of the file. Click one and it starts. When you quit it, you come back to
GSLauncher.

Starting it with the computer
-----------------------------
Open the Control Panel (Apple menu), then Set Start. Choose "Select
Application" and pick GSLauncher. From now on GS/OS starts GSLauncher instead
of the Finder. "Quit to Finder" in its File menu takes you to the Finder.

Finding apps
------------
The first time GSLauncher starts (there is no Launcher.Slots file yet) it
opens Find Apps, and you can open it again with Find Apps... (Apple-F) in
the File menu. Check the disks to look at (the boot disk is checked) and
click Scan; then check the S16 and ProDOS 8 apps you want and click Add
Selected. Esc stops a scan.

Slots
-----
Up to 18 apps a page, five in a row, and up to 4 pages (tabs; Page menu).
Keys 1 to 9 start the first nine slots of a page. The View menu chooses
what shows under each name: the file date, when it was last started, or how
often. Restart and Shut Down are in the File menu.
 Add App... (Apple-N) asks for an application
(an S16 or a ProDOS 8 SYS file) and puts it in a new slot.

To change slots, choose Edit Slots (Apple-E): the title says Edit Slots,
and a click picks a slot (a frame round it) instead of starting it. The
arrow keys pick the next one. Then:

  Change Slot...   another application for it
  Rename Slot...   the name under its icon (empty: the file's name)
  Remove Slot      it goes
  Move Left/Right  it moves along the row

Choose Edit Slots again (or press Escape) to go back to starting apps.

The Help menu explains all of this in the program.

The slots are kept in Launcher.Slots, a text file next to GSLauncher:
one line a slot, name=path, for example

  GS Commander=*:GSCommander:GSCommander

("*" is the disk you started from.) You can edit it with any text editor.

Icons
-----
GSLauncher shows the app's icon from the Finder's icon files: in an Icons
folder next to the app, or else in the Icons folder of its disk. An app
with no icon gets a plain one. A slot whose file is missing shows its icon
dimmed and "not found" under its name.

The date under the name is when the file was last changed: handy for seeing
that a new build has arrived.

2026 Walter Tengler.
