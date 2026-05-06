# npm remote control

a tiny macOS app that floats over your editor with one-click buttons for every npm script.

**[⬇ Download DMG](https://github.com/a10k/npm-remote-control/releases/latest/download/npm-remote-control.dmg)** · macOS 26 · no install · no config

---

## setup

1. open the dmg, drag **npm remote control** to Applications
2. drop the app into your project folder — right next to `package.json`
3. that's it. it finds your scripts automatically.

---

## what it does

| action | result |
|---|---|
| click a script | runs it, shows a spinner |
| click again while running | toggles the live terminal output |
| click × | kills the whole process tree, clears output |
| right-click a failed script | **Reset** — clears the error badge |
| edit `package.json` | panel updates live |
| quit the app | everything it started dies with it |

---

## releasing a new version

push a version tag and GitHub Actions builds and attaches the DMG automatically:

```bash
git tag v1.0.0 && git push origin v1.0.0
```

### no-gatekeeper setup (optional but recommended)

without this, downloaded builds show a Gatekeeper warning on other people's macs. add these secrets to your GitHub repo → Settings → Secrets:

| secret | what it is |
|---|---|
| `DEVELOPER_ID_CERT` | base64-encoded Developer ID `.p12` — `base64 -i cert.p12` |
| `DEVELOPER_ID_CERT_PASSWORD` | password for the `.p12` |
| `APPLE_ID` | your Apple ID email |
| `APPLE_ID_PASSWORD` | an [app-specific password](https://support.apple.com/en-us/102654) |
| `APPLE_TEAM_ID` | 10-char team ID from developer.apple.com |

once set, every release is automatically signed, notarized, and stapled — opens on any mac without warnings.

---

## build from source

```bash
git clone https://github.com/a10k/npm-remote-control
cd npm-remote-control
make dmg   # → build/release/npm-remote-control.dmg
```

requires macOS 26 and Xcode 26.

