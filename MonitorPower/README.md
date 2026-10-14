<div align="center">

# ⚡ Monitor Power

**Decide whether your MacBook charges from your USB-C monitor, with one switch in the menu bar.**

[![Release](https://img.shields.io/github/v/release/s4nj33b/test?include_prereleases&label=release&color=blue)](https://github.com/s4nj33b/test/releases)
![macOS](https://img.shields.io/badge/macOS-12%2B-black?logo=apple)
![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-M1%20%E2%80%93%20M4-orange)
![Swift](https://img.shields.io/badge/Swift-AppKit-F05138?logo=swift&logoColor=white)
[![Build](https://github.com/s4nj33b/test/actions/workflows/monitor-power.yml/badge.svg)](https://github.com/s4nj33b/test/actions/workflows/monitor-power.yml)

[**Download**](https://github.com/s4nj33b/test/releases) · [Features](#-features) · [Install](#-installation) · [How to use](#-how-to-use) · [FAQ](#-faq) · [Build from source](#-building-from-source)

</div>

---

## 🤔 The problem

USB-C monitors with **Power Delivery** charge your MacBook as soon as you plug in the cable. macOS has no setting to turn this off. You may not want it to, because:

- 🔋 **Battery health.** Sitting at 100% on a desk all day wears out the battery faster.
- 🌡️ **Heat.** Charging warms the Mac up.
- 🔌 **Weak monitors.** Some monitors supply too little power and make the Mac charge slowly or unpredictably.
- 🎛️ **Control.** You may want to use the battery while docked and charge only when you choose.

**Monitor Power** puts a switch in the menu bar so you can turn charging from the monitor on or off.

---

## ✨ Features

| | Feature | Description |
|---|---|---|
| 🎚️ | **One-click toggle** | A *Charge from Monitor* switch right in the menu bar. |
| 🔋 | **Stop charging** | Turn the switch off: the Mac keeps running on the monitor's power and the battery stays at its current level. |
| 🪫 | **Run on Battery** | A second switch: the Mac stops drawing power from the adapter and runs on its battery, giving the battery a healthy discharge while the cable stays plugged in. |
| 📉 | **Discharge target slider** | Choose 10–80%. When the battery reaches it, the discharge ends and the Mac goes back to the monitor's power automatically. |
| 📊 | **Live status** | Battery %, charging state and the monitor's wattage. |
| 🛡️ | **Safe by default** | Quitting or uninstalling always restores normal charging. |
| 🔁 | **Self-healing** | Re-applies your setting after sleep, after a reboot, and when you re-plug the cable. |
| 🚀 | **Launch at Login** | Starts quietly with your Mac (macOS 13+). |
| 🧩 | **No Terminal needed** | Install from a DMG. Setup takes one password prompt. |

### The menu

```
 ⚡︎ ─┬──────────────────────────────────────────────┐
     │  Charge from Monitor                 [ ◯━━ ] │  ← charge or not
     │  Run on Battery                      [ ━━◯ ] │  ← discharge cycle
     │  Discharge down to 20%, then use monitor power │
     │  10% ──────●─────────────────────────── 80%   │
     ├──────────────────────────────────────────────┤
     │  Battery: 76% · Discharging                  │
     │  Power Source: Battery (until 20%)           │
     ├──────────────────────────────────────────────┤
     │  Launch at Login                          ✓  │
     ├──────────────────────────────────────────────┤
     │  Monitor Power 0.02                          │
     │  Uninstall…                                  │
     │  Quit Monitor Power                      ⌘Q  │
     └──────────────────────────────────────────────┘
```

The menu bar icon shows the current state: **⚡ `bolt`** while charging is allowed, **`bolt.slash`** while it is off, and **🔋 `battery.25`** while a discharge cycle is running.

---

## 📋 Requirements

| | Requirement |
|---|---|
| 💻 | **MacBook with Apple Silicon** (M1, M2, M3, M4 and later) |
| 🍎 | **macOS 12 Monterey** or later (Launch at Login needs macOS 13 Ventura or later) |
| 🖥️ | A USB-C / Thunderbolt monitor (or dock) that supplies power |
| 🔑 | An administrator account (needed once, during setup) |

> [!IMPORTANT]
> Turn off macOS **Optimized Battery Charging** first: **System Settings → Battery → Battery Health → ⓘ**. Also quit any other charge limiter, such as AlDente or batt. Otherwise they and Monitor Power will override each other.

> [!NOTE]
> Intel Macs are **not supported**. They do not have the charge-control keys this app uses.

---

## 📦 Installation

### Option A: DMG (recommended, no Terminal)

1. **Download** the latest `MonitorPower-<version>.dmg` from the [**Releases**](https://github.com/s4nj33b/test/releases) page.
2. **Open** the DMG and **drag Monitor Power into Applications**.

   ```
   ┌──────────────────────────────────────┐
   │   ⚡ Monitor Power   ──▶   📁 Applications │
   └──────────────────────────────────────┘
   ```
3. **Open Monitor Power** from your Applications folder. On the first launch, follow [Opening the app the first time](#-opening-the-app-the-first-time) below.
4. When asked, click **Install Helper** and enter your Mac password.
5. Look for the **⚡** icon in the menu bar. Setup is done.

> [!TIP]
> If you open the app straight from the DMG, it offers to **move itself to Applications**. Click *Move to Applications*.

### 🔓 Opening the app the first time

Monitor Power is free and open source, and it is not signed with a paid Apple Developer ID. The first time you open it, macOS says it *"cannot verify"* the app. This is expected. You only need to allow it once.

<details>
<summary><b>macOS 15 Sequoia and later</b></summary>

1. Double-click **Monitor Power**. A warning appears. Click **Done**.
2. Open **System Settings → Privacy & Security**.
3. Scroll down to the message about *"Monitor Power" was blocked* and click **Open Anyway**.
4. Confirm with your password or Touch ID, then click **Open Anyway** again.

</details>

<details>
<summary><b>macOS 14 Sonoma and earlier</b></summary>

1. In Applications, **right-click** (or Control-click) **Monitor Power** and choose **Open**.
2. Click **Open** in the dialog.

</details>

<details>
<summary><b>Terminal alternative</b></summary>

```bash
xattr -dr com.apple.quarantine /Applications/MonitorPower.app
```

</details>

### Option B: build from source

See [Building from source](#-building-from-source).

---

## 🎮 How to use

### Charge from Monitor

| Switch | What happens |
|:---:|---|
| **ON** 🟢 | Normal behaviour: the MacBook runs on the monitor's power **and charges**. |
| **OFF** ⚪ | The MacBook **stops charging**. It keeps running on the monitor's power and the battery stays at its current level. |

### 🪫 Run on Battery (healthy discharge)

A lithium-ion battery that sits at the same charge all day, every day, ages faster. Running on battery now and then gives it a healthy discharge, without unplugging the cable.

| Switch | What happens |
|:---:|---|
| **ON** 🟢 | The Mac **stops using the power adapter** and runs on its battery, even though the monitor is still connected. The status shows *Discharging*. |
| **OFF** ⚪ | The Mac uses the monitor's power again. |

**Discharge target slider:** 10%–80% in 5% steps, default 20%.

- When the battery **reaches the target**, the discharge cycle ends on its own. **Run on Battery** turns off and the Mac goes back to the monitor's power.
- What happens next depends on **Charge from Monitor**:
  - **On:** the battery charges back up.
  - **Off:** the battery stays at the target level.
- If the battery is already at or below the target, Run on Battery won't start. The menu tells you to lower the target first.
- Moving the slider **above** the current level during a discharge ends it immediately.

```
Battery %   100 ─┐
                 │╲   Run on Battery: discharging
                 │ ╲
                 │  ╲
    target   20 ─┤───●╱╱╱╱╱  Charge from Monitor ON:  charges back up
                 │    ●━━━━━  Charge from Monitor OFF: held at the target
             0  ─┴──────────────────────────────▶ time
```

> [!TIP]
> For a typical healthy cycle, set the target to **20–40%**, turn on **Run on Battery**, and leave **Charge from Monitor** on. The Mac discharges, then charges back up by itself.

> [!NOTE]
> A discharge cycle survives restarts of the app and of the Mac, as long as **Launch at Login** is on. Quitting the app always returns the Mac to normal charging.

---

## 🛠️ How it works

```
┌─────────────────────────┐    sudo -n     ┌────────────────────────┐   IOKit    ┌───────────┐
│  MonitorPower.app       │ ─────────────▶ │  /usr/local/bin/       │ ─────────▶ │  AppleSMC │
│  menu bar UI · user     │  fixed verbs   │  smc-power  · root     │  SMC write │  firmware │
└─────────────────────────┘                └────────────────────────┘            └───────────┘
```

1. **The System Management Controller (SMC)** is the chip that manages charging on a Mac. Apple Silicon Macs have hidden SMC settings that pause charging or ignore the power adapter. Tools such as AlDente and batt use the same settings.
2. **Only root can write to the SMC.** A small C helper, `smc-power`, does the writes. It accepts **exactly four commands** and nothing else:

   | Command | Effect | SMC keys written |
   |---|---|---|
   | `allow` | Normal charging | adapter on, charging on |
   | `inhibit` | Charge from Monitor off | `CHTE` (or `CH0B` + `CH0C` on older firmware) |
   | `block` | Run on Battery | `CHIE` (or `CH0I` on older firmware) |
   | `status` | Read-only report | — |

3. **During setup**, the helper is installed to `/usr/local/bin/smc-power`, owned by root. A sudoers rule is added at `/etc/sudoers.d/monitor-power`. The rule lets **only your user** run **only those four commands** without a password. It is checked with `visudo` before it is installed.
4. **The app** saves your settings and applies them again on launch, after the Mac wakes from sleep, and whenever macOS reports a power change that shows charging restarted on its own.

### 🔐 Security

- The helper cannot be used to write arbitrary SMC keys, run other programs or read files.
- The sudoers rule names the exact binary path and exact arguments.
- The helper is copied from inside the code-signed app bundle. **Uninstall** removes both the helper and the sudoers rule.

---

## 🗑️ Uninstalling

**From the app:** click the menu bar icon → **Uninstall…** → enter your password. Then drag **Monitor Power** from Applications to the Trash.

**From Terminal** (in a clone of this repository):

```bash
cd MonitorPower
./scripts/uninstall.sh
```

Both methods restore normal charging, remove the helper and the sudoers rule, and delete the app's settings.

---

## ❓ FAQ

<details>
<summary><b>The switch is off, but my Mac is still charging.</b></summary>

- Make sure **Optimized Battery Charging** is off and no other battery app is running.
- Check that the menu does not show a ⚠︎ message. If it says *Setup not finished*, choose **Install Helper…**.
- Your Mac's firmware may use different SMC keys. Run `smc-power status` in Terminal and include the output in an issue.

</details>

<details>
<summary><b>Does the setting survive a reboot?</b></summary>

The SMC resets on every reboot. Turn on **Launch at Login** so Monitor Power re-applies your setting automatically.

</details>

<details>
<summary><b>What happens if I quit the app?</b></summary>

Normal charging is restored immediately. Your Mac is never left unable to charge.

</details>

<details>
<summary><b>My monitor flickers for a moment when I flip the switch.</b></summary>

Some monitors renegotiate USB-C Power Delivery when the Mac changes how it uses power. This is harmless.

</details>

<details>
<summary><b>Will this damage my Mac?</b></summary>

The app only writes settings that macOS and the firmware already support for charge management. These are the same settings AlDente and batt use. Even so, they are undocumented, so use the app at your own risk.

</details>

<details>
<summary><b>Why does it need my password?</b></summary>

macOS only lets root write to the SMC. You enter your password once, during setup. After that, the narrow sudoers rule lets the switch work without asking.

</details>

---

## 🧑‍💻 Building from source

**Prerequisites:** macOS 12+, Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/s4nj33b/test.git
cd test/MonitorPower

./scripts/build-dmg.sh   # one step: build, verify and show build/MonitorPower-<version>.dmg
make app                 # build/MonitorPower.app (helper included)
make dmg                 # build/MonitorPower-0.02.dmg
make dmg VERSION=0.03    # set a custom version
./scripts/install.sh     # build, install the helper and copy the app to /Applications
```

### Project layout

```
MonitorPower/
├── App/
│   ├── Info.plist                  # bundle metadata (LSUIElement = menu bar only)
│   ├── MonitorPower.entitlements   # hardened-runtime entitlements
│   └── Sources/
│       ├── main.swift              # app entry point
│       ├── AppDelegate.swift       # menu, switches, slider, setup flow
│       ├── PowerController.swift   # calls the helper via sudo -n
│       ├── PowerSourceMonitor.swift# battery %, charging state, power events
│       └── HelperInstaller.swift   # one-time admin setup from inside the app
├── helper/
│   └── smc-power.c                 # root helper that writes SMC keys
├── scripts/
│   ├── build-dmg.sh                # one-step DMG build (optionally notarized)
│   ├── helper-install.sh           # installs or removes the helper and sudoers rule
│   ├── install.sh                  # build and install from source
│   └── uninstall.sh                # full removal
├── Makefile                        # app / helper / dmg / notarize targets
└── RELEASE_NOTES.md
```

### Using the helper directly

```bash
smc-power status          # mode=allow|inhibit|block and which keys this Mac supports
sudo smc-power inhibit    # stop charging, keep using USB-C power
sudo smc-power block      # run from battery
sudo smc-power allow      # restore normal behaviour
```

### Releases

The [GitHub Actions workflow](../.github/workflows/monitor-power.yml) builds the app and the DMG on an Apple Silicon macOS runner for every change. To publish a release, **create a release on GitHub** (Releases → *Draft a new release*, with any tag such as `0.02`). The workflow builds the DMG and attaches it to that release within a few minutes. You can also run the workflow manually from the **Actions** tab with a `release_tag` input. That attaches the DMG to an existing release, or creates the release if it does not exist.

### 🔏 Notarization

Notarized builds open with no Gatekeeper warning. Notarization needs a paid **[Apple Developer Program](https://developer.apple.com/programs/)** membership (US$99/year).

#### 1. Create a Developer ID certificate (one time)

1. Join the Apple Developer Program and note your **Team ID** (see [developer.apple.com/account](https://developer.apple.com/account) → Membership details).
2. On your Mac, open **Xcode → Settings → Accounts**, sign in, select your team, click **Manage Certificates…**, then **+ → Developer ID Application**.
3. Open **Keychain Access → My Certificates**, right-click **Developer ID Application: Your Name (TEAMID)**, choose **Export…**, and save it as `cert.p12` with a strong password.

#### 2. Create an app-specific password

Go to [account.apple.com](https://account.apple.com) → **Sign-In and Security → App-Specific Passwords** and generate one named "notarytool". `notarytool` uses this password, never your real Apple ID password.

#### 3a. Notarize locally

```bash
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="ABCDE12345"
export APPLE_APP_PASSWORD="abcd-efgh-ijkl-mnop"

make clean
make notarize SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)"
```

This signs the helper and the app with the hardened runtime and a secure timestamp, builds and signs the DMG, submits it to Apple, waits for approval (usually 1–10 minutes), staples the ticket to the DMG and verifies it with `spctl`.

If Apple rejects it, fetch the log:

```bash
xcrun notarytool history --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"
xcrun notarytool log <submission-id> --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD"
```

#### 3b. Notarize in GitHub Actions

Add these under **Settings → Secrets and variables → Actions → New repository secret**:

| Secret | Value |
|---|---|
| `MACOS_CERT_P12` | Output of `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | The password you set when exporting `cert.p12` |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_TEAM_ID` | Your 10-character Team ID |
| `APPLE_APP_PASSWORD` | The app-specific password |

With `MACOS_CERT_P12` set, every workflow run signs with Developer ID and notarizes, and every release gets a notarized DMG. Without it, builds stay ad-hoc signed as before.

---

## ⚠️ Known limitations

- **Not notarized yet.** Releases are ad-hoc signed and need the one-time approval described [above](#-opening-the-app-the-first-time) until the [notarization secrets](#-notarization) are configured.
- **Undocumented SMC keys.** Apple has renamed these keys before (`CH0B` became `CHTE` in macOS 15.7 firmware) and could do so again.
- **Apple Silicon only.**
- **One user per Mac.** The sudoers rule is written for the user who ran setup. Another user on the same Mac must run **Install Helper…** themselves, which replaces the rule.

---

## 🗺️ Roadmap

- [x] Notarization support in the build ([setup](#-notarization))
- [ ] Publish notarized releases
- [ ] App icon
- [ ] Hold the battery at a target level (charge up to X%, then stop)
- [ ] Per-monitor profiles (remember a setting for each display)
- [ ] Universal (Intel) support where the firmware allows it

---

## 🙏 Acknowledgements

The SMC key research comes from the open-source battery tools [**batt**](https://github.com/charlie0129/batt) and [**AlDente**](https://github.com/AppHouseKitchen/AlDente-Battery_Care_and_Monitoring), and from the classic `smc.c` by devnull.

<div align="center">

Made for MacBooks that live on a desk. ⚡

</div>
