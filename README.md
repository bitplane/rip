---
features: ["asciinema"]
---
# `rip`

bash scripts for batch ripping computer CDs/DVDs/floppy disks and uploading to archive.org

## ▶️ `SETUP.EXE`

It'll grumble at startup if you don't have the following:

```bash
sudo apt install tmux gddrescue tree imagemagick \
                 eject genisoimage archivemount icoutils \
                 imagemagick mtools fuseiso p7zip-full udftools pigz
pip install "internetarchive~=5.3"
```

Configure `internetarchive` with `ia configure` or it'll cry when you run it.

## 🖼️ `PIC.ICO`

![pic](pic/pic.cast.webp)

## 🏃 `Autorun.inf`

Either run `./scrip/n.stage.sh` as background tasks, or run it in tmux:

```bash
./rip.sh
```

This will create a session with a general monitor pane, plus outputs from each
stage of the pipeline:

1. `rip` - taking a CD, DVD, or floppy disk from the drive and reading it with `ddrescue`. The
   log files are included. `rip-all` launches one process per drive, which is
   default.
2. `snip` - collects metadata, like the file date of the youngest file, the file
   tree 
3. `zip` - compresses the image with `pigz`.
4. `ship` - uploads it to archive.org
5. `sip` - is what you do when you're finished 🍻

Each step in the pipeline is just a dir with files in it. The main dir name is
the name of the internet archive item, and everything that doesn't begin with
`.` will be uploaded. If something fails, see `archive.log` to see why.

Metadata is kept in the `.meta` dir, with tags as subdirs. You can inspect and
edit the metadata with `dip`.

## 🤓 `MANUAL.DOC`

Since everything is just a dir containing files, you can move them about and
mess with them to re-queue them. So you don't need to just use it with
CDs/DVDs/floppies; you can add whatever work you like to the `ship` dir.

You can also `source ./scrip/libs.sh` and use the functions manually. By
convention these start with `name_` from the `lib_name.sh`.

## ℹ️  `META.INF`

The name of the dir itself becomes the IA item name.

All files that don't start with a `.` will be uploaded.

Metadata fields are stored in `.meta/name/n` and can be added with the helper
in `lib_upload.sh` like so:
```sh
echo "weather"    | meta_add subject "./met-office-climate-data"
echo "historical" | meta_add subject "./met-office-climate-data"
```

## 🔗 `PROJECT.LNK`

* [🏠 home](https://bitplane.net/dev/sh/rip)
* [🐱 github](https://github.com/bitplane/rip)

### 🌍 `RELATED.LNK`

* [📺 yt-mpv](https://bitplane.net/dev/python/yt-mpv) -
  archive youtube videos after watching them in an ad-free player.
* [🤷 shruggingface](https://bitplane.net/dev/python/shruggingface) -
  library to take AI models out of HuggingFace's walled garden.

## ⚖️ `LICENSE.TXT`

WTFPL with one additional clause:

1. Don't blame me.
