## Monitor Power 0.01 — first preview release

Control whether your MacBook charges from a USB-C monitor, right from the menu bar.

### Features
- **Charge from Monitor** switch in the menu bar.
- Two "off" modes:
  - **Stop Charging**: run on the monitor's power without charging the battery.
  - **Disconnect Monitor Power**: run on the battery and ignore the monitor's power.
- A **low-battery threshold slider (10–80%)**. In Disconnect mode, the Mac switches to the monitor's power when the battery reaches this level.
- Live battery %, charging state and monitor wattage in the menu.
- Setup inside the app: one administrator password prompt, no Terminal needed.
- Launch at Login (macOS 13+) and a built-in **Uninstall…** option.

### Install
1. Download `MonitorPower-0.01.dmg` below and open it.
2. Drag **Monitor Power** into **Applications**.
3. Open it from Applications. This build is not notarized by Apple, so macOS blocks the first launch:
   - **macOS 15 and later:** after the warning, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   - **macOS 14 and earlier:** right-click the app, choose **Open**, then click **Open** again.
4. Click **Install Helper** and enter your Mac password.

### Requirements
- Apple Silicon MacBook (M1 or later)
- macOS 12 Monterey or later

### Known limitations
- The app is ad-hoc signed, not notarized by Apple.
- It uses undocumented SMC keys, which Apple may change in future firmware.
