# `rip`

bash scripts for batch uploading ISOs to the Internet Archive.

## `SETUP.EXE`

It'll grumble at startup if you don't have the following:

```bash
sudo apt install tmux fuseiso gddrescue tree xz-utils
pip install internetarchive
```

## `PIC.ICO`

![pic](pic/pic.cast.webm)

## `Autorun.inf`


Either run `./scrip/n.stage.sh` as background tasks, or run run it in tmux:

```bash
./rip.sh
```

This will create a session with a general monitor pane, plus outputs from each
stage of the pipeline:

1. `rip` - taking a CD or DVD from the drive and reading it with `ddrescue`. The
   log files are included.
2. `snip` - takes metadata, like the file date of the youngest file, file tree
   and potentially other things in future (ico to png, readme.txt etc).
3. `zip` - compressing it with `xz`
4. `ship` - uploading it to archive.org

Each step in the pipeline is just a dir with files in it. The main dir name is
the name of the internet archive item, and everything that doesn't begin with
`.` will be uploaded. If something fails, see `archive.log` for why.

The `.date` file is used to tag the item with a creation date. The `.info` one
is for the main description.

If you have multiple drives, it's probably safe to run multiple copies of the
`rip` script.

## 🔗 links

* [🏠 home](https://bitplane.net/dev/sh/rip)
* [🐱 github](https://github.com/bitplane/rip)

## ⚖️ LICENSE.TXT

WTFPL with one additional clause:

1. Don't blame me.

