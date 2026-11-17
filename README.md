# Mitsubishi Q/R Series Dual-PLC Local Supervisory System — V2.2.1

Offline-first mobile supervisory interface for a Mitsubishi MELSEC-Q Q03UDECPU and an iQ-R Series PLC, using an ESP32 DevKit (exact module/flash size to be confirmed from the physical board) as the local web/API gateway.

## Operating model

- **Primary application:** served directly from the ESP32 at `http://<ESP32-IP>/`. The ESP32 serves the full HMI from LittleFS and communicates with the PLCs over the RUBY local network. This is the reliable operating path and does not require internet access.
- **Public GitHub Pages site:** a small launcher at `dist/hosted/`. It accepts the ESP32 private LAN address and performs a top-level navigation to the ESP32-hosted HMI. It does not relay PLC traffic or expose control through the public site.
- **No public port forwarding:** the ESP32 and PLCs must remain on the private RUBY network.

## Hardware and network register

| Device | Working configuration | Status |
|---|---|---|
| TP-Link router RUBY | `192.168.3.1/24`, 2.4 GHz Wi-Fi | Reported |
| Q-Series PLC | Q03UDECPU, `192.168.3.30:5010`, MC Protocol 3E Binary | Physical verification pending |
| R-Series PLC | R04 family, `192.168.3.20:5010`, SLMP/3E Binary | Exact CPU/port/mapping verification pending |
| ESP32 DevKit | Wi-Fi station, DHCP `192.168.3.x`, HTTP port 80 | Runtime address shown on LCD/Serial Monitor |

Do not assume the ESP32 address is always `.238`; DHCP may change it. Read the current address from the ESP32.

## I/O model

- Q-Series inputs **X0–X7** are independently monitored.
- Q-Series outputs **Y20–Y27** are individually displayed and are supported as independent control candidates.
- **Y0 is prohibited.**
- R-Series input/output mapping remains provisional until the actual CPU and installed I/O modules are verified. R-Series physical writes remain locked.
- Physical write gates are **disabled by default** for both PLCs. Do not enable them until the physical commissioning checklist and machine safety review are complete. PLC memory read-back is not proof of physical load current or actuator movement.

## Quick start for the lab operator

1. Power on RUBY and connect both PLC Ethernet ports to its LAN or an appropriate switch.
2. Power the ESP32 using an appropriate regulated supply.
3. Confirm the ESP32 has joined RUBY. Read its IP from the 16×2 LCD or Arduino Serial Monitor at 115200 baud.
4. Connect the phone/laptop to RUBY.
5. Open `http://<ESP32-IP>/` directly. This is the primary local entry point.
6. Confirm gateway health and test Q-Series and R-Series monitoring independently.
7. Leave physical output writes locked until commissioning approval.

If starting from the public GitHub Pages launcher, enter the current ESP32 IP and select **Open Local Dashboard**. This performs a browser navigation to the local ESP32 page; the full HMI then uses same-origin API requests.

**No internet available?** GitHub Pages cannot load for a first visit without an internet path. Open the ESP32 IP directly on the RUBY network instead.

## GitHub Pages publishing

The canonical workflow is `.github/workflows/pages.yml`. It first compiles the ESP32 firmware and creates the LittleFS image; it retains those `.bin` files as a 30-day Actions artifact. Only after the build job succeeds does it deploy `dist/hosted/` when a commit reaches `main` or when manually dispatched. After creating the new public repository `SurajYadavx/mitsubishi-qr-plc-supervisory` and pushing this release to `main`, choose **Settings → Pages → Build and deployment → GitHub Actions** if GitHub has not selected the workflow automatically.

Expected project URL after a successful Actions deployment:

`https://surajyadavx.github.io/mitsubishi-qr-plc-supervisory/`

The repository is intended to be public so the friend can open the hosted launcher. Public means source and documentation are publicly readable. Never commit `secrets.h`, Wi-Fi passwords, operator PINs, private keys or personal credentials.

## ESP32 firmware build

From the repository root (PlatformIO Core required):

```powershell
python -m pip install platformio
python -m platformio run -d firmware/esp32_local_gateway
python -m platformio run -d firmware/esp32_local_gateway -t buildfs
```

Create `firmware/esp32_local_gateway/src/secrets.h` from `secrets.example.h` and enter the local RUBY Wi-Fi credentials. **Keep `SECRET_OPERATOR_PIN` empty for the initial monitoring-only lab test.** A private PIN is only provisioned later, after the machine risk review, physical I/O mapping and explicit output-write commissioning approval. Keep the real `secrets.h` untracked; never put credentials in GitHub. Upload firmware and filesystem only after confirming the exact board/COM port and following `docs/esp32-firmware-setup.md`.

## Test commands

```powershell
node --check web/assets/js/app.js
node tests/run_browser_tests.js
node tests/hosted_launcher.test.js
node tests/firmware_security_contract.test.js
python -m unittest discover -s tests -v
python -m unittest gateway/test_unit.py -v
```

See `PUBLISH_READINESS.md` for the independent checks and limitations in this release review, and `reports/V2_2_1_TEST_RESULTS.md` for the historical project-reported results. Physical PLC communication and the ESP32 runtime must be checked in the lab before calling the system commissioned.

## Key documentation

- `docs/architecture-v2.md` — system architecture
- `docs/network-configuration-v2.md` — RUBY and PLC network settings; dynamic ESP32 DHCP address
- `docs/hosted-deployment.md` — public launcher and local dashboard flow
- `docs/offline-operation.md` — internet-free operation
- `docs/control-safety.md` — physical write gates and authorisation
- `docs/physical-commissioning.md` — lab commissioning procedure
- `reports/V2_2_1_COMMISSIONING_CHECKLIST.md` — step-by-step bench checklist

## Legacy components

The older `gateway/`, `agent/`, `firmware/plc_monitor/` and related MQTT/Windows-agent files are retained for project history and compatibility. They are **not required** for the V2.2.1 ESP32 local operating path.
