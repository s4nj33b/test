## Monitor Power 0.02

### New: Run on Battery 🪫
A second switch in the menu bar stops the Mac from drawing power from the monitor or power adapter, so it runs on its battery while the cable stays plugged in. This gives the battery a healthy discharge.

- Set where the discharge stops with the **Discharge target slider** (10–80%, default 20%).
- At the target, the Mac switches back to the monitor's power automatically:
  - With **Charge from Monitor** on, it charges back up.
  - With it off, the battery stays at the target level.
- The menu bar icon changes to a battery while a discharge is running.

### Changed
- **Charge from Monitor → off** now always means *stop charging, keep using monitor power*. The **When Off** submenu is gone. Running on battery is the new **Run on Battery** switch.

### Fixed
- The battery status in the menu now updates live. In 0.01 it showed the previous state, e.g. *Charging* after turning charging off. While the hardware switches over, the menu shows *Starting to Charge…*, *Stopping Charging…* or *Switching to Battery…*.

### Install
1. Download `MonitorPower-0.02.dmg` below and open it.
2. Drag **Monitor Power** into **Applications**, replacing 0.01 if it is installed.
3. Open it from Applications. This build is not notarized by Apple, so macOS blocks the first launch:
   - **macOS 15 and later:** after the warning, open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   - **macOS 14 and earlier:** right-click the app, choose **Open**, then click **Open** again.
4. Click **Install Helper** if asked, and enter your Mac password.

### Requirements
- Apple Silicon MacBook (M1 or later)
- macOS 12 Monterey or later

### Known limitations
- The app is ad-hoc signed, not notarized by Apple.
- It uses undocumented SMC keys, which Apple may change in future firmware.
