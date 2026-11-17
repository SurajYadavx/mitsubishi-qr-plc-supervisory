# ESP32 Firmware Development & Flashing Guide
## Project V2 — Central Embedded Dual-PLC Gateway

---

## 1. Firmware Overview

The Project V2 gateway firmware runs on an Espressif ESP32 DevKit. It functions as an autonomous, high-availability embedded bridge that:
1. Connects to the local TP-Link `RUBY` 2.4 GHz Wi-Fi network.
2. Hosts a high-speed HTTP web server serving static HMI assets from LittleFS flash memory.
3. Provides a RESTful JSON API: `/api/v1/health`, `/api/v1/system`, `/api/v1/devices`, `/api/v1/devices/{device_id}/telemetry`, `/api/v1/devices/{device_id}/diagnostics`, and explicit `/api/v1/devices/{device_id}/outputs/{point_id}/command` routes for Y20–Y27.
4. Maintains non-blocking, concurrent MC Protocol 3E binary TCP connections to:
   - Station 1: Mitsubishi Q03UDECPU (`192.168.3.30:5010`)
   - Station 2: Mitsubishi iQ-R (reported R04 family; exact CPU suffix and `192.168.3.20:5010` endpoint provisional)
5. Enforces safety allowlists, Y0 prohibitions, fail-closed write gates, and optional private PIN validation; post-write read-back is PLC memory-bit verification only.
6. Drives a 16x2 I2C diagnostic LCD display with graceful headless fallback.

Firmware source directory: `firmware/esp32_local_gateway/`

---

## 2. Directory Structure

The browser verification harness is kept under the repository `tests/` directory; it is not copied to the ESP32 LittleFS image. The embedded `data/` folder contains only the HMI assets that the device serves.

```text
firmware/esp32_local_gateway/
├── platformio.ini              # PlatformIO environment configuration
├── esp32_local_gateway.ino     # Arduino IDE primary sketch entry point
├── README.md                   # Quick hardware & flashing summary
├── data/                       # LittleFS static web filesystem
│   ├── index.html              # Industrial Supervisory HMI
│   └── assets/
│       ├── css/style.css       # Complete responsive HMI styling
│       └── js/app.js           # Frontend logic & control state machine
└── src/
    ├── config.h                # Hardware pins, IP addresses & safety allowlists
    ├── secrets.example.h       # Credentials template (WIFI SSID, PIN)
    ├── secrets.h               # Git-ignored private credentials (created locally)
    ├── mc_protocol.h           # MC Protocol 3E binary frame builder & parser
    ├── mc_protocol.cpp
    ├── plc_manager.h           # Non-blocking dual-PLC poller & telemetry cache
    ├── plc_manager.cpp
    ├── lcd_display.h           # 16x2 I2C LiquidCrystal diagnostic driver
    ├── lcd_display.cpp
    ├── web_server.h            # LittleFS file streamer & REST API handlers
    ├── web_server.cpp
    └── main.cpp                # Setup & cooperative multitasking event loop
```

---

## 3. Hardware Requirements & Wiring

| Component | Specification | Connection to ESP32 |
|---|---|---|
| **ESP32 DevKit** | Exact module/board variant to be read from the physical board | Use only the documented power input for that board |
| **I2C LCD Display** | 16x2 Character LCD + PCF8574 I2C Backpack | SDA -> GPIO 21, SCL -> GPIO 22, VCC -> 5V, GND -> GND |
| **Power Supply** | 5V DC 2A Regulated (or DC-DC Buck Converter) | VCC -> VIN, GND -> GND |

> [!CAUTION]
> **DC-DC Buck Converter Safety Rule:**
> If using a DC-DC converter, select it and wire it according to the ESP32 board and converter manufacturers' specifications. With the ESP32 disconnected, have a qualified person verify the converter output using a suitable meter before connecting the board. Never apply 24V directly to an ESP32 pin, USB input or 5V/VIN input unless the exact board documentation explicitly rates that input for it.

---

## 4. Environment Setup & Configuration

### 4.1 Step 1: Create `secrets.h`
Copy `src/secrets.example.h` to `src/secrets.h`:
```powershell
Copy-Item "firmware\esp32_local_gateway\src\secrets.example.h" "firmware\esp32_local_gateway\src\secrets.h"
```
Edit `src/secrets.h` with your real RUBY Wi-Fi password. Keep `SECRET_OPERATOR_PIN` empty during initial monitoring tests:
```cpp
#pragma once

#define SECRET_WIFI_SSID       "RUBY"
#define SECRET_WIFI_PASSWORD   "YOUR_REAL_RUBY_WIFI_PASSWORD"

// Keep empty during monitoring-only commissioning. Set a private PIN only
// after the physical write gate has been deliberately enabled and safety signed off.
#define SECRET_OPERATOR_PIN    ""
```
*(Note: `secrets.h` is explicitly included in `.gitignore` and must never be committed to Git. Do not use a default or sample PIN. The safe `secrets.example.h` template is tracked in Git.)*

---

## 5. Build and Flash Instructions

### Method A: PlatformIO (Recommended)

1. Open a terminal in the firmware directory:
   ```powershell
   cd firmware\esp32_local_gateway
   ```
2. Build the firmware binary:
   ```powershell
   pio run
   ```
3. Connect the ESP32 to your PC via USB and upload the application binary:
   ```powershell
   pio run -t upload
   ```
4. Upload the static web filesystem (`data/` directory) to ESP32 LittleFS flash:
   ```powershell
   pio run -t uploadfs
   ```
5. Open the serial monitor at 115200 baud to monitor startup:
   ```powershell
   pio device monitor -b 115200
   ```

### Method B: Arduino IDE 2.x

1. Install ESP32 Board Support in Arduino IDE:
   - Go to **Preferences** -> **Additional Board Manager URLs**.
   - Add: `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`
   - Open **Boards Manager**, search for `esp32` by Espressif Systems, and click **Install**.
2. Install Required Libraries via **Library Manager**:
   - `ArduinoJson` (by Benoit Blanchon) -> Install version **7.x**.
   - `LiquidCrystal I2C` (by Frank de Brabander or Marco Schwartz) -> Install version **1.1.x**.
3. Open `esp32_local_gateway.ino`.
4. Configure Board Settings:
   - **Board:** ESP32 Dev Module
   - **Partition Scheme:** Default 4MB with spiffs/littlefs (1.2MB App / 1.5MB SPIFFS/LittleFS)
   - **Upload Speed:** 921600 (or 115200 for older USB-UART chips)
5. Click **Upload** to flash the sketch.
6. To upload the `data/` directory in Arduino IDE 2.x, install the **ESP32 LittleFS Filesystem Uploader** tool extension, or use the PlatformIO CLI `pio run -t uploadfs`.

---

## 6. Verification and Boot Diagnostics

Upon successful boot, the serial monitor (115200 baud) prints the initialization sequence:

```text
========================================
Q/R DUAL-PLC EMBEDDED GATEWAY
System Version: 2.2.1
Hardware Target: ESP32 DevKit
========================================
[LCD] Initializing I2C bus (SDA=21, SCL=22)...
[LCD] I2C LCD detected at address 0x27
[FS] Mounting LittleFS filesystem...
[FS] LittleFS mounted successfully.
[WIFI] Connecting to SSID: RUBY...
[WIFI] Connected! IP: 192.168.3.x (RSSI: -52 dBm)
[PLC] Initializing Dual-PLC Manager...
[PLC] Station 1: Q03UDECPU -> 192.168.3.30:5010 (Permitted: Y20, Banned: Y0)
[PLC] Station 2: iQ-R (provisional) -> 192.168.3.20:5010 (Configuration unverified; outputs LOCKED)
[HTTP] Starting WebServer on Port 80...
[HTTP] Routes registered: /api/v1/health, /api/v1/system, /api/v1/devices, station telemetry/diagnostics, and Y20–Y27 commands (write gates default false)
[SYSTEM] Gateway initialization complete. Entering cooperative loop.
```

If the I2C LCD is connected:
- **Line 1:** `IP:192.168.3.x `
- **Line 2:** `Q:OK R:-- W:52dBm`
*(Adjust the blue potentiometer on the back of the PCF8574 I2C backpack using a small screwdriver if characters appear faded or washed out).*
