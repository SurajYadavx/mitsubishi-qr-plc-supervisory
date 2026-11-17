# V2.2.1 Publish-Readiness and Independent Verification

**Review date:** 17 November 2026  
**Package:** `PROJECT_V2_2_1_PUBLISH_READY.zip`

## Release architecture decision

- New repository: `SurajYadavx/mitsubishi-qr-plc-supervisory`.
- Existing `SurajYadavx/mitsubishi-q-plc-app` is not modified.
- One canonical workflow: `.github/workflows/pages.yml`. It first compiles the ESP32 firmware and builds the LittleFS filesystem; only a successful build can proceed to the Pages deployment job. It publishes only `dist/hosted/` and retains generic no-secrets firmware binaries as a 30-day Actions artifact. These are compile-validation outputs, not flash-ready lab images because the RUBY Wi-Fi password is deliberately excluded.
- Hosted page is a launcher; normal HMI operation is served from the ESP32 at `http://<ESP32-IP>/`.
- No cloud MQTT broker or Windows gateway is required for the V2.2.1 local ESP32 path.

## Checks run in this review environment

| Check | Result |
|---|---|
| Dashboard JavaScript syntax (`node --check web/assets/js/app.js`) | PASS |
| Legacy agent Python syntax (`python -m py_compile agent/service.py`) | PASS |
| Git staging simulation (safe example tracked; actual secrets/build caches excluded) | PASS — 148 files staged in a temporary copy; no real secrets or local build artifacts included |
| ESP32 HMI HTML/JS synchronization | PASS — HTML and JS byte-identical between `web/` and LittleFS data |
| ESP32 CSS synchronization | PASS — CSS content identical; only line-ending normalization differs |
| Safe credential template tracking (`secrets.example.h`) | PASS — template included by Git; real `secrets.h` remains ignored |
| Legacy Python agent physical actuation | HARDENED — disabled by default; requires per-PLC legacy enable flag and a private environment PIN |
| Existing browser suite (`node tests/run_browser_tests.js`) | 165 PASS, 0 FAIL, 0 SKIP |
| ESP32 same-origin API security | PASS — wildcard CORS/PNA allow headers removed; OPTIONS requests return HTTP 403; local HMI remains same-origin |
| Firmware security contract tests (`node tests/firmware_security_contract.test.js`) | 10 PASS, 0 FAIL |
| Hosted launcher behavior tests (`node tests/hosted_launcher.test.js`) | 7 PASS, 0 FAIL |
| ZIP integrity (`unzip -t`) | PASS |
| Secret file scan for real `secrets.h`, `secrets.ini`, `.env`, private keys/certificates | No matching real secret files present |
| Pages / firmware workflow | One canonical workflow; generic no-secrets firmware and LittleFS build gate runs before Pages deployment |
| Local PlatformIO compilation | NOT RUN — PlatformIO is not installed in this review environment; the first GitHub Actions run will perform a generic no-secrets build and block Pages deployment on failure. The friend must compile locally with an ignored `secrets.h` before flashing |
| Firmware build in this review environment | NOT RUN — PlatformIO is not installed here |
| Full Python suite in this review environment | PARTIAL / BLOCKED — 57 test/discovery entries attempted; 7 test modules failed import and 1 was skipped because `pymcprotocol`, `pymodbus`, and related development dependencies are absent in this Python 3.13 review container |
| Physical Q/R PLC communication | NOT TESTED — requires the lab PLCs and RUBY network |
| ESP32 Wi-Fi/LCD/HTTP runtime and flash | NOT TESTED — requires the physical board |
| Phone browser end-to-end operation on RUBY | NOT TESTED — requires the friend’s phone, router and ESP32 |

The AntiGravity V2.2.1 report previously stated that the PlatformIO build succeeded and that the Python/browser suites passed in its development environment. Those are historical project-reported results; they are not represented here as independently reproduced.

## Known constraints intentionally retained

1. GitHub Pages must be public for GitHub Free and needs internet to load initially.
2. The ESP32 uses DHCP; its live IP must be read from the board or router. `.238` and `.50` are historical examples, not fixed assignments.
3. The hosted launcher uses a user-initiated top-level navigation to the ESP32 page; it does not make a cross-origin API fetch. Actual dashboard use still requires the phone to be connected to the RUBY LAN (or a routed network that can reach the ESP32). A browser may show an HTTP security/local-network warning; the page does not bypass the browser or OS security model.
4. Q and R physical write gates remain disabled by default. This is deliberate fail-closed behavior, not a deployment defect.
5. R-Series CPU suffix, Ethernet endpoint and X/Y map are still provisional until the physical rack and project configuration are checked.
6. HTTP on the isolated lab LAN is not encrypted. Do not expose the ESP32 or PLC ports to the public internet.

## Required physical acceptance before declaring the product commissioned

- Verify ESP32 joins RUBY and note its actual address.
- Open `http://<ESP32-IP>/` directly from a phone on RUBY.
- Confirm `/api/v1/health`, `/api/v1/system`, device list and telemetry are valid.
- Verify Q-Series `X0–X7` monitoring and independent `Y20–Y27` read-back against PLC indicators/programming software.
- Verify R-Series CPU and I/O map; leave its control locked until verified.
- Check stale telemetry/offline indication and reconnect behavior by disconnecting/reconnecting each PLC separately.
- Keep physical output writes disabled during this first acceptance pass. Any later actuation test requires a safe, isolated load, verified point-to-terminal mapping, machine risk review, emergency stop, and deliberate private credential provisioning.

**Conclusion:** the release bundle and automated pre-deployment build gate are ready to publish. The public launcher will only deploy after GitHub Actions successfully compiles the ESP32 firmware and LittleFS image. The full hardware product cannot be called field-verified or guaranteed functional until the firmware is flashed and the physical acceptance checks above pass. GitHub repository creation and Pages configuration are still a user-side publishing step because the connected GitHub interface available in this session does not expose repository-creation or Pages-settings administration.
