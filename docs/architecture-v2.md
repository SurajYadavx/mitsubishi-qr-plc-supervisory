# Project V2 Architecture Specification
## Q/R Series Dual-PLC Local Network Supervisory and Control System

> **V2.2.1 operating-path note:** The full HMI is served from ESP32 LittleFS at `http://<ESP32-IP>/`. GitHub Pages is only a public launcher that navigates to that local HMI; it is not the live dashboard or an API proxy. The ESP32 API is same-origin only and deliberately does not allow cross-origin CORS requests. See [`hosted-deployment.md`](hosted-deployment.md) and [`browser-compatibility.md`](browser-compatibility.md) for the release's exact browser/network behavior.

---

## 1. System Identity and Executive Summary

**Project Name:** Q/R Series Dual-PLC Local Network Supervisory and Control System (Project V2)  
**System Classification:** Industrial Embedded Supervisory Control and Data Acquisition (SCADA) Gateway & Mobile HMI  
**Target Controllers:** 
- Primary Station 1: Mitsubishi Electric MELSEC-Q Series (`Q03UDECPU`)
- Secondary Station 2: Mitsubishi Electric iQ-R Series (`R04CPU / R04ENCPU`, provisional model classification)
**Network Environment:** Dedicated air-gapped industrial LAN hosted on standalone router (`RUBY`)  
**Central Gateway:** Espressif ESP32 DevKit (Embedded Wi-Fi to Dual-PLC TCP Gateway)

---

## 2. Architectural Paradigm Shift: V1 vs. V2

### 2.1 The Legacy Architecture (V1.6.0)
The historical implementation relied on a multi-hop, cloud-dependent and host-dependent pipeline:
```text
[ Physical Q-PLC ]
       │  (MC Protocol 3E / TCP)
[ Windows Python Gateway (COM9) ]
       │  (USB Serial JSON + Stop-and-Wait ACK)
[ ESP8266 NodeMCU Bridge ]
       │  (Wi-Fi WPA2 + TLS 1.2)
[ EMQX Cloud MQTT Broker ]
       │  (WSS / Port 8084)
[ Web Browser Client (GitHub Pages) ]
```
*V1 Limitations:* Required a running Windows laptop running Python, USB serial bridges, active internet connectivity for EMQX Cloud, and cloud MQTT latency. Output actuation was strictly prohibited in software.

### 2.2 The Project V2 Architecture
Project V2 eliminates all cloud brokers, external internet dependencies, USB serial transports, and permanently tethered laptop gateways. The ESP32 DevKit assumes full ownership of local communication, web hosting, and telemetry caching:

```text
                        ┌─────────────────────────────────────────┐
                        │        OPERATOR CLIENT TIER             │
                        │ Mobile Phones & Lab Workstations        │
                        │ HMI opened from ESP32 same-origin URL    │
                        └────────────────────┬────────────────────┘
                                             │ HTTP / REST (Port 80)
                                             │ Same-origin local web app
                        ┌────────────────────┴────────────────────┐
                        │      LOCAL NETWORK INFRASTRUCTURE       │
                        │        TP-Link Router ("RUBY")          │
                        │        Subnet: 192.168.3.0/24           │
                        │         Wi-Fi: 2.4 GHz 802.11b/g/n      │
                        │         Ethernet LAN: 100BASE-TX        │
                        └────────────────────┬────────────────────┘
                                             │ Wi-Fi Station (DHCP 192.168.3.x)
                        ┌────────────────────┴────────────────────┐
                        │       CENTRAL EMBEDDED GATEWAY          │
                        │            ESP32 DevKit                 │
                        │  - LittleFS Static Web Server (Port 80) │
                        │  - RESTful JSON API (/api/v1/...)       │
                        │  - Dual-Socket Non-Blocking MC Poller   │
                        │  - Output Safety Allowlist & PIN Auth   │
                        │  - 5-Stage Verification Pipeline Tracker│
                        │  - 16x2 I2C Diagnostic Display (0x27)   │
                        └──────────┬───────────────────┬──────────┘
                                   │                   │
         MC Protocol 3E Binary/TCP │                   │ SLMP / MC Protocol 3E Binary/TCP
         Port 5010 (Subcmd 0x0001) │                   │ Port 5010 (Subcmd 0x0003)
                                   ▼                   ▼
                     ┌──────────────────┐ ┌────────────────────────┐
                     │ STATION 1 (Q-PLC)│ │ STATION 2 (R-PLC)      │
                     │  Q03UDECPU       │ │  R04CPU / R04ENCPU     │
                     │  192.168.3.30    │ │  192.168.3.20          │
                     │  Port: 5010      │ │  Port: 5010            │
                     │  - X0..X7 (In)   │ │  - X0..X7 (In, prov)   │
                     │  - Y20..Y27 (Out)│ │  - Y20..Y27 (Out, prov)│
                     │  - Y20..Y27 (Gate│ │  - Outputs LOCKED      │
                     │    Control Coil) │ │    (Pending Lab Verif) │
                     └──────────────────┘ └────────────────────────┘
```

---

## 3. Subsystem Breakdown

### 3.1 Network Tier: Standalone Router RUBY
- **Subnet:** `192.168.3.0/24` (Subnet mask `255.255.255.0`).
- **Default Gateway / DNS:** `192.168.3.1`.
- **Operating Mode:** Fully isolated local access point (air-gapped; WAN port disconnected).
- **Wi-Fi SSID:** `RUBY` (2.4 GHz band mandatory for ESP32 802.11b/g/n radio).
- **Physical Ethernet:**
  - LAN Port 1: Mitsubishi Q-Series PLC (`192.168.3.30`).
  - LAN Port 2: Mitsubishi iQ-R Series PLC (`192.168.3.20`).
  - LAN Port 3: Engineering Maintenance Workstation (`192.168.3.10`).

### 3.2 Embedded Gateway Tier: ESP32 DevKit
- **Microcontroller target:** PlatformIO `esp32dev` / ESP32 DevKit profile. Confirm the exact physical module and flash size printed on the board before flashing; the partition profile assumes a 4 MB flash device.
- **Flash Partitioning:** PlatformIO default partition profile with LittleFS filesystem (`data/` directory hosting static HTML/CSS/JS).
- **Embedded Web Server:** High-throughput `WebServer` serving:
  - Static HMI assets: `/index.html`, `/assets/css/style.css`, `/assets/js/app.js`. The browser test harness lives under repository `tests/` and is not flashed to LittleFS.
  - Dynamic API:
    - `GET /api/v1/system`: Gateway uptime, heap, network IP, MAC, LCD status.
    - `GET /api/v1/devices`: Registered device catalog (`melsec_q03`, `melsec_r04`).
    - `GET /api/v1/devices/{device_id}/telemetry`: Normalized telemetry batches.
    - `GET /api/v1/devices/{device_id}/diagnostics`: Socket health, poll cycles, timeouts, error counts.
    - `POST /api/v1/devices/{device_id}/outputs/{point_id}/command`: Output actuation with PIN auth.
- **PLC Poller Engine:** Cooperative, non-blocking polling loops running on 200 ms intervals:
  - Separate `WiFiClient` TCP sockets for Station 1 (`192.168.3.30:5010`) and Station 2 (`192.168.3.20:5010`).
  - Asynchronous state machines with connect, send, wait-response, unpack, and timeout phases.
  - Complete fault isolation: communication failure or disconnect on Station 2 does not impair or stall telemetry from Station 1.
- **Local Diagnostics:** 16x2 I2C LiquidCrystal display (address `0x27`, SDA GPIO 21, SCL GPIO 22):
  - Line 1: Wi-Fi RSSI and IP address.
  - Line 2: Station 1 & 2 link status (`Q:OK R:--`) and last fault code.
  - Auto-detection: runs headless without freezing if display is unpowered or disconnected.

### 3.3 Controller Tier: Dual Mitsubishi Stations

#### Station 1: MELSEC Q-Series (`Q03UDECPU`)
- **IP / Port:** `192.168.3.30:5010` (Static configuration via GX Works2 Built-in Ethernet).
- **Protocol:** MC Protocol 3E Binary format (Command `0x0401` batch read, Command `0x1401` batch write).
- **Subcommand:** `0x0001` (Bit units, 3-byte address, 1-byte device code `0x9C` for X, `0x9D` for Y).
- **Monitored Points:**
  - Inputs: `X0`, `X1`, `X2`, `X3`, `X4`, `X5`, `X6`, `X7`.
  - Outputs: `Y20`, `Y21`, `Y22`, `Y23`, `Y24`, `Y25`, `Y26`, `Y27`.
- **I/O Architecture (V2.2):** Independent 8-channel inputs (`X0–X7`) and outputs (`Y20–Y27`). No ladder coupling exists on the physical test bench.
- **Authorized Control Outputs:** All 8 points `Y20`, `Y21`, `Y22`, `Y23`, `Y24`, `Y25`, `Y26`, `Y27` (hex offsets `0x20`–`0x27`). Protected by fail-closed gate (`Q_PLC_WRITES_ENABLED false` by default).
- **Banned Point:** `Y0` is strictly rejected and never monitored or commanded.

#### Station 2: MELSEC iQ-R Series (`R04CPU / R04ENCPU`, Provisional)
- **IP / Port:** `192.168.3.20:5010` (Static configuration via GX Works3 Module Parameter).
- **Protocol:** SLMP / MC Protocol 3E Binary format (Command `0x0401` batch read, Command `0x1401` batch write).
- **Subcommand:** `0x0003` (Bit units, 4-byte address, 2-byte device code `0x9C 0x00` for X, `0x9D 0x00` for Y).
- **Provisional Points:** `X0..X7`, `Y20..Y27`.
- **Operational Status:** Strictly Read-Only (Control outputs locked in software until physical CPU model, network card, and ladder interlocks are verified in the laboratory).

### 3.4 Operator Client Tier: Mobile & Desktop Browsers
- **Offline Delivery:** Assets served directly from ESP32 LittleFS flash. Works without internet access.
- **Same-origin API policy:** The HMI's browser requests target the origin that served the page. The firmware deliberately sends no permissive CORS/Private Network Access headers and rejects `OPTIONS` preflight requests. Cross-origin hosted-dashboard API access is not supported.
- **Public launcher:** An optional GitHub Pages page validates the private ESP32 address and performs a user-initiated top-level navigation to the ESP32; it does not relay telemetry or control commands.
- **Mobile Responsive Design:** Multi-tier fluid grid layout optimized for smartphone touchscreens.
- **ISA-101 Situational Awareness:** High contrast, low-glare dark palette by default, muted colors for normal states, vibrant amber/red exclusively for alarms.
- **5-Stage Verification Pipeline UI:** Step-by-step visual tracker rendering every stage of an output command.

---

## 4. Supervisory Control Architecture & Safety Interlocks

### 4.1 Safety Principles
1. **Never Write on Boot:** All output registers and coils remain untouched during system initialization.
2. **Strict Output Allowlist:** Only explicitly enumerated point IDs may be commanded (`melsec_q03: ["Y20", "Y21", "Y22", "Y23", "Y24", "Y25", "Y26", "Y27"]`). All others (including `Y0`) are rejected immediately. Fail-closed safety gates keep writes disabled by default.
3. **Permanent Y0 Prohibition:** Point `Y0` was mistakenly included in early conceptual sketches. In the physical machine, `Y0` may be tied to critical emergency circuits. It is hardcoded as a safety violation across all firmware, backend, and frontend validators.
4. **Mandatory Operator PIN:** When the station write gate is deliberately enabled, every permitted actuation requires a locally provisioned private credential (`X-Operator-PIN` header and/or `auth_pin` JSON field). The public example and firmware fallback PIN are empty; empty or placeholder credentials fail closed.
5. **Station 2 Lockout:** Station 2 outputs cannot be actuated from the UI or gateway until physical commissioning is complete.
6. **PLC Memory Read-Back:** Only after the write gate, Y0 prohibition, PIN, allowlist and communication checks pass does the gateway issue a read command (`0x0401`) after the write (`0x1401`) and PLC completion response. This verifies the PLC memory bit only.
7. **Read-back Mismatch Alert:** A mismatch between the requested state and the PLC memory-bit read-back is reported. It does not detect or prove physical contact closure, field voltage, load current, or actuator movement; verify those independently.

### 4.2 5-Stage Verification Pipeline
Every actuation request is subject to the following checks. In the default V2.2.1 build, the physical-write gate is false and the firmware rejects the request before PIN validation or PLC network dispatch:
```text
[ Stage 1: Station Gate ]
       │  • Verify target device is known
       │  • Check station write gate; default is false
       │  • If false, return PHYSICAL_WRITES_DISABLED (HTTP 403)
       │    before PIN validation or PLC network dispatch
       ▼
[ Stage 2: Point and Credential Validation ]
       │  • Reject Y0 (no HTTP route is registered for Y0)
       │  • Require a locally provisioned private PIN
       │  • Validate state and station-specific output allowlist
       ▼
[ Stage 3: Protocol Frame Assembly & Dispatch ]
       │  • Build MC Protocol 3E Binary frame (0x1401)
       │  • Q-series: subcommand 0x0001; Y device code 0x9D
       │  • Send to the configured PLC endpoint only after checks pass
       ▼
[ Stage 4: PLC Execution & Endcode Check ]
       │  • Receive and validate the PLC response frame
       │  • Inspect the PLC end code (success is 0x0000)
       ▼
[ Stage 5: PLC Memory Read-Back ]
       │  • Issue the 0x0401 bit-read for the commanded point
       │  • Compare PLC memory-bit state with requested state
       │  • This is NOT proof of physical field/load operation
       │  • Surface memory read-back status to the operator UI
```

---

## 5. Telemetry Semantics & Data Quality

### 5.1 The Valid-Zero Invariant
In industrial automation, digital state `0` (False / OFF) is valid physical information, NOT an error or absence of data.
- **Raw Value `0` / `False`:** Must be packaged with `DataQuality.GOOD` and rendered as `OFF (Open / De-energized)`.
- **Communication Failure / Timeout:** Must be packaged with `DataQuality.COMM_FAILURE` and `raw_value = None`. Rendered as `UNKNOWN / COMM FAILURE` (never rendered as `OFF`, which could mislead an operator into believing an energized circuit is safe).

---

## 6. Preservation of Historical Capabilities

The repository maintains full backward compatibility for previous development phases:
1. **Windows Local Agent (`agent/`):** FastAPI application with background polling, Windows Credential Manager integration, and local telemetry cache.
2. **Modbus TCP Adapter (`adapters/modbus/`):** Industrial Modbus TCP client supporting coils, discrete inputs, input registers, and holding registers.
3. **Simulation Adapter (`core/simulated_adapter.py`, `core/simulated_control_adapter.py`):** Deterministic in-memory simulated controllers for testing without hardware.
4. **Gateway Flow Control (`gateway/`):** Python serial transport with stop-and-wait ACK protocol and ESP8266 firmware retained under `firmware/plc_monitor/`.
