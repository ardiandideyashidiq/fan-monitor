#!/bin/sh
# uninstall.sh - remove fan-monitor.
#   curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/uninstall.sh | sudo sh
#   or from a local clone: sudo ./uninstall.sh
set -eu

die() { echo "uninstall.sh: ERROR: $1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must run as root - e.g. pipe into 'sudo sh'"
command -v systemctl >/dev/null 2>&1 || die "systemd is required (systemctl not found)"

systemctl stop fan-monitor.service 2>/dev/null || true
systemctl disable fan-monitor.service 2>/dev/null || true
rm -f /etc/systemd/system/fan-monitor.service \
      /usr/local/bin/fan_monitor \
      /usr/local/bin/fancontrol \
      /usr/local/bin/fanctl \
      /etc/default/fan-monitor
systemctl daemon-reload || true

echo "uninstall.sh: fan-monitor removed."
echo "uninstall.sh: NOTE: stopping the service leaves the fan ON by design (safety)."
echo "uninstall.sh: Any exported gpio was left in place; reboot to fully clear it."
