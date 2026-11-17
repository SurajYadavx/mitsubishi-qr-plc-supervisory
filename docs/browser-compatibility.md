# Browser compatibility and local-network operation — V2.2.1

## Supported operating model

The full supervisory HMI is hosted by the ESP32 LittleFS web server and is opened at:

`http://<ESP32-IP>/`

The phone or laptop must be connected to the RUBY LAN (or another network explicitly routed to the ESP32). The web page and its `/api/v1/...` requests share the same HTTP origin. The supported workflow therefore does **not** depend on cross-origin API access, CORS permission headers, Private Network Access preflights, or an HTTPS reverse proxy.

The optional public GitHub Pages site is only a launcher. It accepts the ESP32's private address and performs a user-initiated top-level navigation to the ESP32. It does not fetch telemetry or issue PLC commands from the public origin.

## Cross-origin access is deliberately disabled

V2.2.1 does not expose the ESP32 REST API to arbitrary websites. Firmware responses do not include `Access-Control-Allow-Origin` or `Access-Control-Allow-Private-Network`; `OPTIONS` preflight requests are rejected. This is intentional because the normal HMI is served from the same ESP32 origin. Do not re-enable wildcard CORS to make an externally hosted dashboard talk directly to the gateway.

A static page hosted on GitHub Pages cannot be treated as the live HMI. Use it to open the private ESP32 URL, then operate the HMI from that local page. Browser attempts to call the ESP32 API from a different website are unsupported and may fail by design.

## Browser and device considerations

- Use a current browser on the phone/laptop. Test the actual device planned for lab use; this package does not claim exhaustive compatibility across every browser and operating-system release.
- A browser or operating system may show a local-network access prompt, insecure-HTTP indicator, or Wi-Fi-without-internet warning. The wording and available controls vary by device.
- Keep the device connected to RUBY and choose the option that retains that Wi-Fi connection when its internet uplink is absent. Cellular fallback can make the private ESP32 address unreachable.
- Do not disable browser security, enable broad “insecure content” exceptions, install unknown certificates, or expose the ESP32 using public port forwarding to work around a warning.
- If the public launcher cannot load because the lab network has no internet connection, bypass it and enter `http://<ESP32-IP>/` directly while connected to RUBY.

## Cache and API behavior

- HMI files are served from ESP32 LittleFS and use a one-hour static-asset cache. After firmware/filesystem updates, perform a hard refresh or clear the site cache if the browser continues showing an old UI.
- API responses are marked no-cache by the firmware where appropriate; always judge connectivity using the current health and telemetry timestamps, not a cached screenshot.
- If LittleFS does not mount, the ESP32 serves a diagnostic fallback page. Rebuild and upload the filesystem image with PlatformIO (`pio run -t buildfs` / `pio run -t uploadfs`) rather than formatting automatically.

## Verification before using the bench

1. Connect the client device to RUBY.
2. Read the ESP32's current DHCP IP from its LCD, Serial Monitor (115200 baud), or router lease table.
3. Open `http://<ESP32-IP>/` directly.
4. Verify `/api/v1/health`, `/api/v1/system`, the device list and each PLC's telemetry through the dashboard.
5. Keep physical writes disabled during initial network and monitoring checks.

The public launcher, browser tests and static source checks do not replace physical validation on the actual phone, ESP32, router and PLC rack.
