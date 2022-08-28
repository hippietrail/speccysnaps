# speccysnaps

MacOS commandline tool to resursively list all Sinclair ZX Spectrum snapshot files

Give one or more paths on the commandline, otherwise it will process just your home folder

Currently only `.sna` and `.z80` files are supported

For `.z80` files, some information about the snapshot will be listed:

- Whether it's a version 1, version 2, or version 3 .z80 snapshot
- For version 1 files, whether or not the RAM data is compressed
- For version 3 files, whether it's a short version or a long version with an extra field in the header
- For version 2 & 3 files, which variety of Spectrum hardware the snapshot is for

# TODO

- Create a thumbnail image for every snapshot
- Support other snapshot formats, tape formats, disk formats, microdrive formats, and cartridge formats
- Support zip files containing snapshots
