# fan-monitor

On/off GPIO fan controller for ARM boards, as a systemd service.
Fan is either fully **ON** or fully **OFF** — no PWM speed levels.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/install.sh | sudo sh
```

With options:

```sh
curl -fsSL https://raw.githubusercontent.com/ardiandideyashidiq/fan-monitor/main/install.sh \
  | sudo sh -s -- --on 60000 --off 45000 --gpio 507 --interval 20
```

## Configure

Edit `/etc/default/fan-monitor`, then `sudo systemctl restart fan-monitor`.

| Variable     | Default                               | Meaning                  |
| ------------ | ------------------------------------- | ------------------------ |
| `GPIO`       | `507`                                 | GPIO number driving the fan |
| `TEMP_INPUT` | `/sys/class/hwmon/hwmon0/temp1_input` | temp input (millidegrees C) |
| `INTERVAL`   | `20`                                  | poll interval (seconds)  |
| `CPU_HI`     | `60000`                               | fan ON at/above (60 °C)  |
| `CPU_LOW`    | `45000`                               | fan OFF at/below (45 °C) |

In between, the previous state is kept (hysteresis). Stopping the service forces the fan **ON** as a precaution.

## Manual control

```sh
sudo fancontrol off     # stop auto control, force fan OFF
sudo fancontrol on      # stop auto control, force fan ON
sudo fancontrol auto    # resume automatic control
fancontrol status       # temp, fan and service state
```

Manual `on`/`off` is sticky — the service stays stopped until `auto`.

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

## Hardware

Default `GPIO=507` is `GPIOAO_6`, the fan pin on the HG680P. On other boards
**confirm your fan pin first** — the wrong GPIO toggles the wrong hardware.

## License

MIT — see `LICENSE`.
