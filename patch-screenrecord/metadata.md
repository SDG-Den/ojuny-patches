name: Screen recording
id: patch-screenrecord
description: GPU screen recording with audio, webcam overlay, format and resolution selection, and replay buffer
dependencies:
version: 1

# Screen recording

This patch installs the `ojuny-screenrecord` wrapper, an optional replay buffer,
audio capture, and a patch-scoped webcam overlay. It is off by default.

## Scope

- The webcam overlay belongs to this patch only. It is driven by
  `ojuny-screenrecord webcam-start`, `webcam-stop` and `webcam-toggle`, and by
  the `SUPER+ALT+W` bind when `webcam.enable` is true.
- There is no standalone camera page and no detection UI. Camera capture itself
  works out of the box on the supported hosts; use the camera application you
  already have for general use. The options here only control the recording
  overlay.
- The overlay is a floating `WebcamOverlay` window included in the captured
  region. It is not a separate recording source.

## Webcam options

| Option | Default | Meaning |
| --- | --- | --- |
| `webcam.enable` | `false` | Start the overlay with a recording and add the toggle bind. |
| `webcam.device` | `""` | V4L2 node. Empty probes `/dev/video*` and picks the first node that reports a capture format, so a UVC metadata node is not chosen by enumeration order. |
| `webcam.size` | `medium` | Overlay height preset: 270, 405, or 540 pixels. |
| `webcam.position` | `bottom-right` | Overlay corner inside the recorded region or active monitor. |
| `webcam.crop` | `8:9` | Camera crop shape. |
| `webcam.format` | `null` | Four-character V4L2 pixel format. `null` keeps the device default. |
| `webcam.resolution` | `null` | `WxH` capture size. `null` keeps the device default. |

`webcam.format` and `webcam.resolution` are nullable. When both are `null` the
wrapper never calls `v4l2-ctl` and the device keeps whatever the kernel and the
camera application selected. A non-null format must be exactly four characters,
and a non-null resolution must match `^[0-9]+x[0-9]+$`. Both are checked by an
assertion only while the patch is active.

The selected format is applied with `v4l2-ctl --device "$device"
--set-fmt-video=...` before mpv starts. The argument is built only from the
non-null parts: width and height from `webcam.resolution`, and `pixelformat`
from `webcam.format`. If the kernel rejects the combination, the wrapper sends
one notification and continues with the device default. A rejected webcam format
never aborts the recording.

## Listing devices and formats

```
ojuny-screenrecord list-devices
ojuny-screenrecord list-formats
ojuny-screenrecord list-formats /dev/video0
```

`list-formats` runs `v4l2-ctl --list-formats-ext` and prints one line per
discrete combination: device node, fourcc, and `WxH`. Without an argument it
walks every `/dev/video*` node. Nodes that cannot report formats are skipped.

## Testing

The overlay, format selection, and capture-node probing are implemented but not
yet verified on real hardware. The pending hardware test is: list formats,
select a format and a resolution, start and stop the overlay, and confirm the
wrapper chooses a capture node on a system where the metadata node enumerates
first. Until that test is recorded, treat these controls as untested.
