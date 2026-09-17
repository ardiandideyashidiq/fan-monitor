# fan-monitor

Simple on/off GPIO fan controller for ARM boards, running as a systemd service.
Tested on an HG680P-class Amlogic S905X TV box running Armbian.

It polls a temperature input every few seconds and toggles a sysfs GPIO
that switches the fan. The fan is either fully **ON** or fully **OFF** —
this is not PWM speed control.

## Install (one-liner)

```sh
curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/install.sh | sudo sh
```

With options (flags win over environment variables):

```sh
curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/install.sh \
  | sudo sh -s -- --on 60000 --off 45000 --gpio 507 --interval 20
```

Or from a clone:

```sh
git clone https://github.com/ardiandideyashidiq/fan-monitor.git
cd fan-monitor
sudo ./install.sh
```

Tip: pin to a release tag instead of `main` for reproducible installs,
e.g. `.../v1.0.0/install.sh`.

## Configure

Edit `/etc/default/fan-monitor`, then restart:

```sh
sudo nano /etc/default/fan-monitor
sudo systemctl restart fan-monitor
```

| Variable     | Default                              | Meaning                                  |
| ------------ | ------------------------------------ | ---------------------------------------- |
| `GPIO`       | `507`                                | sysfs GPIO number driving the fan switch |
| `TEMP_INPUT` | `/sys/class/hwmon/hwmon0/temp1_input` | temperature input (millidegrees C)       |
| `INTERVAL`   | `20`                                 | poll interval in seconds                 |
| `CPU_HI`     | `60000`                              | turn fan ON at/above (60 °C)             |
| `CPU_LOW`    | `45000`                              | turn fan OFF at/below (45 °C)            |

Between `CPU_LOW` and `CPU_HI` the previous state is kept (hysteresis),
so the fan does not chatter around a single threshold. When the service
stops, the fan is forced **ON** as a precaution.

## Verify

```sh
systemctl status fan-monitor
journalctl -t FAN_MONITOR -n 10 --no-pager
cat /sys/class/gpio/gpio507/value   # 0 = off, 1 = on
```

## Uninstall

```sh
curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/uninstall.sh | sudo sh
```

## Hardware notes

The default `GPIO=507` is `GPIOAO_6` (aobus-banks line 6), the fan pin on
the HG680P. On any other board, **confirm your fan pin first** — driving
the wrong GPIO toggles the wrong hardware. Useful probes:

```sh
sudo gpioinfo                                   # list chips, lines, consumers
cat /sys/class/gpio/gpiochip*/base /sys/class/gpio/gpiochip*/ngpio
cat /sys/class/hwmon/hwmon*/temp1_input
```

The installer refuses to proceed if the chosen GPIO is not covered by any
gpiochip or if the temperature input is unreadable.

## Security note

Piping `curl` into `sh` runs remote code as root. Prefer inspecting first
(`curl -fsSL <url> | less`) or installing from a clone. The installer is
idempotent and only writes its own three paths:
`/usr/local/bin/fan_monitor`, `/etc/systemd/system/fan-monitor.service`,
`/etc/default/fan-monitor`.

## Development

POSIX `sh` only (works on dash, bash, busybox ash) — no bashisms.
Linted with ShellCheck in CI.

## License

MIT — see `LICENSE`.
