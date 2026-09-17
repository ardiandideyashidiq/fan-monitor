#!/bin/sh
# install.sh - install fan-monitor (GPIO fan controller) as a systemd service.
#
# One-liner:
#   curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/install.sh | sudo sh
#
# With options:
#   curl -fsSL <url>/install.sh | sudo sh -s -- --on 60000 --off 45000 --gpio 507
#
# With environment variables (flags win over these):
#   curl -fsSL <url>/install.sh | sudo FM_GPIO=507 FM_ON=60000 FM_OFF=45000 sh
#
# Or from a local clone:
#   sudo ./install.sh [--gpio N] [--temp PATH] [--interval S] [--on HI] [--off LOW]
#
# Source control (env only): FM_OWNER FM_REPO FM_BRANCH FM_RAW_BASE.
set -eu

PROG=fan-monitor
DAEMON_SRC=fan_monitor
CTL_SRC=fancontrol
UNIT_SRC=fan-monitor.service
DAEMON_DST=/usr/local/bin/fan_monitor
CTL_DST=/usr/local/bin/fancontrol
UNIT_DST=/etc/systemd/system/fan-monitor.service
DEFAULTS_FILE=/etc/default/fan-monitor

OWNER="${FM_OWNER:-ardiandideyashidiq}"
REPO="${FM_REPO:-fan-monitor}"
BRANCH="${FM_BRANCH:-main}"
RAW_BASE="${FM_RAW_BASE:-https://raw.githubusercontent.com/$OWNER/$REPO/$BRANCH}"

die() { echo "install.sh: ERROR: $1" >&2; exit 1; }
info() { echo "install.sh: $1"; }
is_int() { case "$1" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }

usage() {
    cat <<'EOF'
Usage: install.sh [options]
  --gpio N       sysfs GPIO number driving the fan (default 507)
  --temp PATH    temperature input in millidegrees C
                 (default /sys/class/hwmon/hwmon0/temp1_input)
  --interval S   poll interval in seconds (default 20)
  --on HI        turn fan ON at/above HI millidegrees (default 60000)
  --off LOW      turn fan OFF at/below LOW millidegrees (default 45000)
  -h, --help     show this help
Environment variables FM_GPIO / FM_TEMP / FM_INTERVAL / FM_ON / FM_OFF
do the same; command-line flags win.
EOF
}

[ "$(id -u)" -eq 0 ] || die "must run as root - e.g. pipe into 'sudo sh'"
command -v systemctl >/dev/null 2>&1 || die "systemd is required (systemctl not found)"

# An existing config provides the base values; explicit flags/env override it.
explicit=0
if [ -r "$DEFAULTS_FILE" ]; then
    # shellcheck disable=SC1091
    . "$DEFAULTS_FILE"
fi
if [ -n "${FM_GPIO+x}" ]; then GPIO="$FM_GPIO"; explicit=1; fi
if [ -n "${FM_TEMP+x}" ]; then TEMP_INPUT="$FM_TEMP"; explicit=1; fi
if [ -n "${FM_INTERVAL+x}" ]; then INTERVAL="$FM_INTERVAL"; explicit=1; fi
if [ -n "${FM_ON+x}" ]; then CPU_HI="$FM_ON"; explicit=1; fi
if [ -n "${FM_OFF+x}" ]; then CPU_LOW="$FM_OFF"; explicit=1; fi

: "${GPIO:=507}"
: "${TEMP_INPUT:=/sys/class/hwmon/hwmon0/temp1_input}"
: "${INTERVAL:=20}"
: "${CPU_HI:=60000}"
: "${CPU_LOW:=45000}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --gpio) GPIO="${2:?missing value for --gpio}"; explicit=1; shift 2;;
        --temp) TEMP_INPUT="${2:?missing value for --temp}"; explicit=1; shift 2;;
        --interval) INTERVAL="${2:?missing value for --interval}"; explicit=1; shift 2;;
        --on) CPU_HI="${2:?missing value for --on}"; explicit=1; shift 2;;
        --off) CPU_LOW="${2:?missing value for --off}"; explicit=1; shift 2;;
        -h|--help) usage; exit 0;;
        *) die "unknown option: $1 (see --help)";;
    esac
done

is_int "$GPIO" || die "GPIO must be a non-negative integer (got '$GPIO')"
is_int "$INTERVAL" || die "interval must be a positive integer (got '$INTERVAL')"
is_int "$CPU_HI" || die "ON threshold must be an integer (got '$CPU_HI')"
is_int "$CPU_LOW" || die "OFF threshold must be an integer (got '$CPU_LOW')"
[ "$INTERVAL" -ge 1 ] || die "interval must be >= 1"
[ "$CPU_LOW" -lt "$CPU_HI" ] || die "OFF ($CPU_LOW) must be below ON ($CPU_HI)"

[ -d /sys/class/gpio ] || die "sysfs GPIO not available (/sys/class/gpio missing)"
_gpio_ok=0
for _chip in /sys/class/gpio/gpiochip*; do
    [ -d "$_chip" ] || continue
    _base=$(cat "$_chip/base" 2>/dev/null) || continue
    _n=$(cat "$_chip/ngpio" 2>/dev/null) || continue
    is_int "$_base" || continue
    is_int "$_n" || continue
    if [ "$GPIO" -ge "$_base" ] && [ "$GPIO" -lt "$((_base + _n))" ]; then
        _gpio_ok=1
        break
    fi
done
[ "$_gpio_ok" -eq 1 ] || die "GPIO $GPIO is not covered by any gpiochip - wrong pin for this board?"
[ -r "$TEMP_INPUT" ] || die "temperature input not readable: $TEMP_INPUT"

# Prefer files next to this script (local clone); otherwise download them.
case "$0" in
    */*)
        _dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || _dir=""
        ;;
    *) _dir="";;
esac
if [ -z "$_dir" ] && [ -f "./$DAEMON_SRC" ] && [ -f "./$UNIT_SRC" ]; then
    _dir=$(pwd)
fi
if [ -n "$_dir" ] && [ -f "$_dir/$DAEMON_SRC" ] && [ -f "$_dir/$CTL_SRC" ] && [ -f "$_dir/$UNIT_SRC" ]; then
    info "using local files from $_dir"
    cp "$_dir/$DAEMON_SRC" "$DAEMON_DST.tmp"
    cp "$_dir/$CTL_SRC" "$CTL_DST.tmp"
    cp "$_dir/$UNIT_SRC" "$UNIT_DST.tmp"
else
    command -v curl >/dev/null 2>&1 || die "curl is required to download $PROG files"
    info "downloading from $RAW_BASE"
    curl -fsSL "$RAW_BASE/$DAEMON_SRC" -o "$DAEMON_DST.tmp" \
        || die "download failed: $DAEMON_SRC"
    curl -fsSL "$RAW_BASE/$CTL_SRC" -o "$CTL_DST.tmp" \
        || die "download failed: $CTL_SRC"
    curl -fsSL "$RAW_BASE/$UNIT_SRC" -o "$UNIT_DST.tmp" \
        || die "download failed: $UNIT_SRC"
fi
[ "$(head -n 1 "$DAEMON_DST.tmp")" = "#!/bin/sh" ] \
    || die "downloaded daemon failed sanity check"
[ "$(head -n 1 "$CTL_DST.tmp")" = "#!/bin/sh" ] \
    || die "downloaded fancontrol failed sanity check"

if [ "$explicit" -eq 1 ] || [ ! -r "$DEFAULTS_FILE" ]; then
    cat > "$DEFAULTS_FILE" <<EOF
# fan-monitor configuration - edit, then: systemctl restart fan-monitor
# Temperatures are in millidegrees Celsius. Fan turns ON at/above CPU_HI,
# OFF at/below CPU_LOW, and holds its state in between (hysteresis).
GPIO=$GPIO
TEMP_INPUT=$TEMP_INPUT
INTERVAL=$INTERVAL
CPU_HI=$CPU_HI
CPU_LOW=$CPU_LOW
EOF
    chmod 0644 "$DEFAULTS_FILE"
    info "wrote $DEFAULTS_FILE"
else
    info "keeping existing $DEFAULTS_FILE (pass flags/env to change it)"
fi
chmod 0755 "$DAEMON_DST.tmp"
mv "$DAEMON_DST.tmp" "$DAEMON_DST"
chmod 0755 "$CTL_DST.tmp"
mv "$CTL_DST.tmp" "$CTL_DST"
chmod 0644 "$UNIT_DST.tmp"
mv "$UNIT_DST.tmp" "$UNIT_DST"

systemctl daemon-reload
systemctl enable --now fan-monitor.service

sleep 3
systemctl is-active --quiet fan-monitor.service \
    || die "service failed to start - see: journalctl -u fan-monitor"
info "service is active"
if _v=$(cat "/sys/class/gpio/gpio$GPIO/value" 2>/dev/null); then
    info "gpio$GPIO value=$_v (0=off 1=on), temp=$(cat "$TEMP_INPUT" 2>/dev/null) millidegC"
fi
info "recent log:"
journalctl -t FAN_MONITOR -n 5 --no-pager || true
info "done. Tune $DEFAULTS_FILE, then: systemctl restart fan-monitor"
# Drop the old name if a previous install left it behind.
rm -f /usr/local/bin/fanctl
info "manual control: fancontrol on | fancontrol off | fancontrol auto | fancontrol status"
