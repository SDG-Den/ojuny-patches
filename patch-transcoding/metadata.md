name: Transcoding
id: patch-transcoding
description: One-command image, video, and image-to-text conversion with ffmpeg, ImageMagick, and fzf
dependencies:
version: 1

## Entry point

`ojuny-transcode` is the entry point. The patch installs it system-wide and
adds Transcode rows to the Ojuny menu when `desktop.ojuny.dankMenu.menu` is
available.

## Explicit use

```sh
ojuny-transcode image photo.png jpg high
ojuny-transcode video clip.mkv mp4 1080p
ojuny-transcode ascii logo.svg --width 100 --mode block
```

`ojuny-transcode interactive [directory]` opens an fzf picker. Explicit modes
never prompt.

Output is written next to the input with a collision suffix. The script uses
its own ffmpeg, ImageMagick, fzf, and libnotify runtime, so it does not depend
on the template multimedia module being enabled.
