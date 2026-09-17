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
sudo fancontrol setup   # interactively change ON/OFF temperatures
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

Tested on:

| Item     | Value                                              |
| -------- | -------------------------------------------------- |
| Box      | HG680P (Amlogic S905X, device-tree model "Meson GXL (S905X) P212") |
| OS       | Armbian 26.8.3 noble (Ubuntu 24.04 LTS base)       |
| Kernel   | 6.1.137-ophub, aarch64                             |
| RAM/CPU  | 1.8 GiB, 4 cores                                   |
| Fan pin  | GPIO 507 (`aobus-banks` line 6, `GPIOAO_6`)        |
| Temp     | `/sys/class/hwmon/hwmon0/temp1_input` (`scpi_sensors`, `aml_thermal`) |

## License

MIT — see `LICENSE`.
