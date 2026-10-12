# Monitor Power

A macOS menu bar app that controls whether a MacBook charges from a USB-C monitor.

- **Toggle on**: the MacBook draws power from the monitor and charges normally.
- **Toggle off**: the MacBook stops charging from the monitor.

## Menu

Click the bolt icon in the menu bar:

| Item | Purpose |
|---|---|
| **Charge from Monitor** switch | On = charge normally, off = stop charging |
| Battery / USB-C status | Live battery %, charging state and adapter wattage |
| **When Off** submenu | Sets what "off" does (see below) |
| **Launch at Login** | Starts the app at login (macOS 13+) |
| **Quit** | Restores normal charging and exits |

The icon is `bolt.fill` while charging is allowed and `bolt.slash.fill` while it is off.

### "When Off" modes

| Mode | Effect | SMC keys |
|---|---|---|
| **Stop Charging** (default) | The Mac runs on the monitor's power, but the battery does not charge. Battery wear stays low. | `CHTE`, or `CH0B` + `CH0C` on older firmware |
| **Disconnect Monitor Power** | The Mac ignores the monitor's power and runs on its battery. | `CHIE`, or `CH0I` on older firmware |

In *Disconnect Monitor Power* mode, a slider under that option sets a battery threshold from 10% to 80%, in 5% steps (default 20%). When the battery reaches the threshold, the app switches to *Stop Charging*. The Mac then runs on the monitor's power and the battery stays at that level instead of draining further. Raise the slider above the current battery level to switch over immediately; lower it to go back to running on battery.

## Requirements

- MacBook with Apple Silicon (M1 or later). Intel Macs do not expose the same charge-control keys.
- macOS 12 or later (13+ for Launch at Login).
- Xcode Command Line Tools: `xcode-select --install`.
- **Turn off macOS "Optimized Battery Charging"** (System Settings → Battery → Battery Health → ⓘ), along with any other charge limiters such as AlDente. Otherwise they will override this app.

## Install

```bash
cd MonitorPower
./scripts/install.sh
```

The script:
1. Builds `MonitorPower.app` and the `smc-power` helper (`make all`).
2. Installs the helper to `/usr/local/bin/smc-power`, owned by root.
3. Adds `/etc/sudoers.d/monitor-power`. This rule lets your user run *only* `smc-power allow|inhibit|block|status` as root without a password. The file is checked with `visudo` before it is installed.
4. Copies the app to `/Applications` and launches it.

Uninstall (also restores normal charging):

```bash
./scripts/uninstall.sh
```

## How it works

```
MonitorPower.app (menu bar, user) ──sudo -n──▶ /usr/local/bin/smc-power (root) ──IOKit──▶ AppleSMC
```

- Only root can write to the SMC. The helper accepts four fixed verbs and nothing else, so the sudoers rule cannot be used to write arbitrary SMC keys.
- The app saves the toggle state and applies it again:
  - on launch,
  - after the Mac wakes from sleep (some firmware resets the keys during sleep),
  - when a power event shows the Mac charging even though the toggle is off (e.g. after re-plugging the cable). These re-applies happen at most once every 30 s.
- When you quit, charging is restored, so the Mac is never left unable to charge after the app exits.

## Manual helper use

```bash
smc-power status          # mode=allow|inhibit|block, plus which keys are supported
sudo smc-power inhibit    # stop charging, keep using USB-C power
sudo smc-power block      # run from battery
sudo smc-power allow      # restore normal behaviour
```

## Limitations

- The SMC keys are undocumented. Apple has changed them before (`CH0B` became `CHTE` in macOS 15.7 firmware), and may change them again.
- SMC charge state resets on reboot. The app re-applies it when it launches, so enable **Launch at Login**.
- Some monitors renegotiate USB-C Power Delivery when the setting changes, which can make the display flicker for a moment.
