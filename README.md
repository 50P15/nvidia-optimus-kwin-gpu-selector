# NVIDIA Optimus KWin GPU Selector

A KDE Plasma 6 panel applet to choose which GPU **KWin** (the Plasma Wayland compositor) renders the desktop on, on NVIDIA Optimus laptops (Intel or AMD integrated GPU + NVIDIA).

It does **not** change which GPU games or apps use, and it never logs you out by itself. Changes apply at the next login.

## Modes

| Mode | What it does |
|---|---|
| Automatic (by connected display) | At login, if a display is connected to the NVIDIA GPU, KWin uses NVIDIA. Otherwise KDE's default is kept. |
| Prefer NVIDIA | KWin always uses NVIDIA (integrated GPU as secondary). |
| Prefer Intel / AMD | KWin always uses the integrated GPU (NVIDIA as secondary, so its outputs keep working). |
| KDE default | Nothing is changed. |

Rendering KWin on the GPU that drives an external monitor can avoid copying every frame between GPUs, which may improve desktop smoothness on that monitor, at the cost of higher power use.

## Requirements

- KDE Plasma 6, **Wayland** session (`KWIN_DRM_DEVICES` has no effect on X11)
- NVIDIA GPU + Intel (`i915`/`xe`) or AMD (`amdgpu`) integrated GPU
- `bash`, `qdbus` (any of `qdbus6`, `qdbus-qt6`, `qdbus`)
- Optional: [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) icon theme for NVIDIA/Intel/AMD logos (simple fallback icons are bundled)

## Install

From Plasma: *Add Widgets… → Get New Widgets… → Download New Plasma Widgets…* and search for "NVIDIA Optimus KWin GPU Selector".

Manually:

```sh
kpackagetool6 -t Plasma/Applet -i package
```

## How it works

When you first choose a mode, the applet copies a small script to
`~/.config/plasma-workspace/env/nvidia-optimus-kwin-gpu-selector.sh`.
Plasma runs it at login, before KWin starts. It reads the mode from
`~/.config/kwin-gpu-selector.conf` and exports `KWIN_DRM_DEVICES` accordingly.
No root access is needed.

## Uninstall

1. Remove the applet: `kpackagetool6 -t Plasma/Applet -r org.sopis.kwingpuselector`
2. Remove the login script and config:

```sh
rm ~/.config/plasma-workspace/env/nvidia-optimus-kwin-gpu-selector.sh ~/.config/kwin-gpu-selector.conf
```

3. Log out and back in.

## License

MIT. NVIDIA, Intel and AMD logos are not included; they are taken at runtime from the installed icon theme and belong to their respective owners.

## Support

If you find this applet useful, you can support my work on Ko-fi. Thank you!

[![Support me on Ko-fi](https://storage.ko-fi.com/cdn/kofi2.png?v=3)](https://ko-fi.com/sopis)
