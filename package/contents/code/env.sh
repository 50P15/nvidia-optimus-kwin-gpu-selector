# Installed by the "NVIDIA Optimus KWin GPU Selector" Plasma applet.
# Sourced by Plasma at login, before KWin starts. Sets the GPU KWin renders on.
# Mode is stored in ~/.config/kwin-gpu-selector.conf. Delete this file to disable it.

_kgs_conf="${XDG_CONFIG_HOME:-$HOME/.config}/kwin-gpu-selector.conf"
_kgs_state="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/kwin-gpu-selector.applied"
_kgs_mode=default
[ -r "$_kgs_conf" ] && _kgs_mode=$(sed -n 's/^MODE=//p' "$_kgs_conf" | head -n1)
case "$_kgs_mode" in intel|amd) _kgs_mode=integrated ;; esac

_kgs_nvidia=
_kgs_igpu=
for _kgs_card in /sys/class/drm/card[0-9]*; do
    case "${_kgs_card##*/}" in *-*) continue ;; esac
    _kgs_drv=$(basename "$(readlink -f "$_kgs_card/device/driver")" 2>/dev/null)
    case "$_kgs_drv" in
        nvidia|nouveau) _kgs_nvidia=${_kgs_card##*/} ;;
        i915|xe|amdgpu) _kgs_igpu=${_kgs_card##*/} ;;
    esac
done

_kgs_applied=default
if [ -n "$_kgs_nvidia" ] && [ -n "$_kgs_igpu" ]; then
    case "$_kgs_mode" in
        auto)
            if grep -qx connected /sys/class/drm/"$_kgs_nvidia"-*/status 2>/dev/null; then
                export KWIN_DRM_DEVICES="/dev/dri/$_kgs_nvidia:/dev/dri/$_kgs_igpu"
            fi
            _kgs_applied=auto
            ;;
        nvidia)
            export KWIN_DRM_DEVICES="/dev/dri/$_kgs_nvidia:/dev/dri/$_kgs_igpu"
            _kgs_applied=nvidia
            ;;
        integrated)
            export KWIN_DRM_DEVICES="/dev/dri/$_kgs_igpu:/dev/dri/$_kgs_nvidia"
            _kgs_applied=integrated
            ;;
    esac
fi

echo "$_kgs_applied" > "$_kgs_state" 2>/dev/null
unset _kgs_conf _kgs_state _kgs_mode _kgs_nvidia _kgs_igpu _kgs_card _kgs_drv _kgs_applied
