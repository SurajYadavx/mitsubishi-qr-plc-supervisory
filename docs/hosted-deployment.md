# Hosted Deployment and ESP32 Local Dashboard — V2.2.1

## Recommended deployment model

Project V2.2.1 uses two delivery paths with a deliberately separated trust boundary:

1. **GitHub Pages launcher:** public HTTPS page at `dist/hosted/`. It accepts the ESP32 private LAN address and performs a user-initiated top-level navigation to the ESP32. It does not proxy PLC traffic and does not submit physical control requests.
2. **ESP32-hosted HMI:** full supervisory application served from LittleFS at `http://<ESP32-IP>/`. Monitoring and any deliberately commissioned control use same-origin requests to the ESP32 API. This path works on the RUBY LAN without internet.

The launcher design avoids relying on cross-origin `fetch()` from a public HTTPS origin to a private HTTP gateway. The ESP32 deliberately sends no permissive CORS headers and rejects `OPTIONS` preflight requests. The full HMI must be opened from the ESP32 origin; external hosted dashboards making direct API calls are not a supported mode. Do not weaken browser security or add wildcard CORS to make that unsupported path work.

## GitHub Pages deployment

The repository has one canonical workflow: `.github/workflows/pages.yml`. It first builds generic ESP32 firmware and the LittleFS image without any local Wi-Fi secrets, then deploys only `dist/hosted/` on pushes to `main` and manual workflow dispatch. Do not add duplicate Pages workflows. The retained 30-day CI binaries prove that the source compiles, but they are **not lab flash images** because they intentionally do not contain the RUBY password.

1. Create the separate public repository `SurajYadavx/mitsubishi-qr-plc-supervisory`.
2. Push the prepared V2.2.1 release source to its `main` branch.
3. In **Settings → Pages → Build and deployment**, choose **GitHub Actions** if it is not selected automatically.
4. Open **Actions** and wait for `Deploy Project V2.2.1 to GitHub Pages` to complete successfully.
5. The expected URL is `https://surajyadavx.github.io/mitsubishi-qr-plc-supervisory/`. It is not live until that workflow succeeds.

For GitHub Free, use a public repository for Pages. A public repository exposes source and documentation, so never commit actual Wi-Fi credentials, operator PINs, private keys or personal tokens. Before flashing the ESP32, copy `firmware/esp32_local_gateway/src/secrets.example.h` to `secrets.h`, enter the actual RUBY SSID/password locally, and run PlatformIO build/upload/uploadfs commands on the engineering PC. `secrets.h` is ignored by Git and must remain local.

## Friend's connection procedure

1. Power on RUBY and both PLCs.
2. Power the ESP32 with a regulated supply matching the board requirements.
3. Confirm Wi-Fi association. Read the current ESP32 DHCP address from the LCD or Serial Monitor at 115200 baud. Do not assume a fixed DHCP address.
4. Connect the phone to RUBY.
5. If the phone has internet, open the public Pages launcher, enter `http://<current-ESP32-IP>` and tap **Open Local Dashboard**.
6. If there is no internet, skip GitHub Pages and open `http://<current-ESP32-IP>/` directly.
7. Verify gateway status and each PLC independently. Keep physical output writes disabled until the commissioning checklist and safety review are completed.

## Browser and network limitations

A public HTTPS page making cross-origin requests to a private HTTP ESP32 is subject to browser Local Network Access, CORS, and secure-context policies. Browser support and user permission prompts vary. V2.2.1 therefore uses top-level navigation from the public launcher to the ESP32-hosted application for the reliable operating path. A top-level navigation is not the same as a cross-origin API fetch.

The hosted launcher still requires internet on first visit. GitHub Pages cannot be loaded when the phone has no path to the internet. The ESP32-hosted application does not have that dependency once firmware and LittleFS are installed.

## Security and commissioning

- Do not configure public port forwarding to the ESP32 or PLCs.
- Keep RUBY isolated from untrusted networks.
- Keep `Q_PLC_WRITES_ENABLED` and `R_PLC_WRITES_ENABLED` false until physical safety sign-off.
- Keep the R-Series output path locked until its CPU model and I/O mapping are verified.
- The operator PIN over local HTTP is an accidental-operation barrier, not encrypted transport. Keep it empty while physical write gates remain disabled; do not provision a PIN or enable writes for initial monitoring.
- PLC memory read-back confirms a PLC bit, not physical load current or actuator movement.
