> **V2.2.1 IP NOTE:** The ESP32 uses DHCP. Do not assume `192.168.3.238` or `192.168.3.50`. Read the current IP from the ESP32 LCD/Serial Monitor and substitute it wherever `<ESP32-IP>` appears. Q `.30` and R `.20` are working/provisional addresses as identified in `docs/network-configuration-v2.md`.

# MITSUBISHI Q/R SERIES DUAL-PLC LOCAL SUPERVISORY SYSTEM
## Field Commissioning and Verification Checklist — Project V2.2.1

**Document ID:** `SOP-Q03-R04-COMM-V2.2.1`  
**Revision:** 2.2.1  
**Target Controllers:** Mitsubishi Q03UDECPU (Station 1), Mitsubishi iQ-R R04 family (Station 2; exact CPU suffix unverified)  
**Gateway Platform:** ESP32 DevKit (exact module and flash size must be confirmed from the physical board)  
**Safety Status:** Fail-closed supervisory prototype; not a safety-rated controller or substitute for hardwired machine safety  

---

## 1. PRE-COMMISSIONING SAFETY MANDATE & INVARIANTS

> [!CAUTION]
> **FAIL-CLOSED POLICY MUST BE MAINTAINED**  
> Physical output writes are strictly disabled by default in both firmware source (`Q_PLC_WRITES_ENABLED = false`, `R_PLC_WRITES_ENABLED = false`) and frontend state. Actuation of physical PLC outputs Y20 through Y27 carries risk of machine movement, solenoid actuation, or electrical contact closure. Do NOT enable physical writes until all Section 2 and Section 3 pre-checks are fully signed off.

### Invariant Rules
1. **Device Point Y0 is Strictly Banned:** Device point `Y0` must never be commanded, polled, or configured. Attempting to write `Y0` must fail closed at UI, REST API, and PLC driver layers.
2. **No Default Credentials:** The firmware example keeps `SECRET_OPERATOR_PIN` empty. Empty, placeholder or wrong PINs fail closed. Keep it empty for monitoring-only acceptance; provision a unique private PIN only after the machine risk review and a separately approved actuation test.
3. **Station 2 Output Lockout:** Station 2 (iQ-R; exact CPU suffix unverified) is provisional read-only monitoring. Its X/Y map is not commissioned, and physical writes remain disabled until the CPU, installed I/O modules, Ethernet settings and GX Works3 project are verified.
4. **Independent FreeRTOS Cores:** The background PLC communication worker runs on Core 0. The HTTP REST web server runs on Core 1. Core 1 web requests must never be blocked by PLC network timeouts.

---

## 2. PHYSICAL BENCH INSPECTION & HARDWARE SETUP

| Step | Item | Description / Verification Requirement | Verified (Y/N) | Initial / Date |
| :---: | :--- | :--- | :---: | :---: |
| **2.1** | **PLC Supply Verification** | A qualified person verifies each PLC power supply against the exact rack/module manufacturer specifications and electrical drawings. Record measured values; do not assume a generic tolerance. | [ ] | ______ / ______ |
| **2.2** | **Protective Earth / Bonding** | Verify protective earth and bonding against the approved panel drawings and manufacturer instructions. Do not create unplanned common-ground connections between isolated supplies. | [ ] | ______ / ______ |
| **2.3** | **ESP32 Supply** | Verify the ESP32 is powered through the input method and voltage supported by the exact board. Never connect 24V directly to an ESP32 pin or USB/5V input unless the board documentation explicitly allows it. | [ ] | ______ / ______ |
| **2.4** | **I2C Bus & 16x2 LCD** | If the 16x2 LCD is installed, verify the documented GPIO21 (SDA) / GPIO22 (SCL) connection and that I2C pull-up voltage is safe for ESP32 3.3V logic. If absent, confirm headless mode is expected. | [ ] | ______ / ______ |
| **2.5** | **Ethernet / Network** | Connect Station 1 Q03UDECPU and Station 2 iQ-R Ethernet interfaces to RUBY LAN (directly or through a suitable switch). The ESP32 joins RUBY over 2.4 GHz Wi-Fi. Verify the actual wiring and link LEDs. | [ ] | ______ / ______ |
| **2.6** | **Q03UDECPU Output Wiring** | Confirm the exact installed output module and terminal allocation in the rack documentation. Verify Y20–Y27 only against the physical module and GX Works2 project. Use appropriately rated, isolated test loads for commissioning. | [ ] | ______ / ______ |
| **2.7** | **Q03UDECPU Input Wiring** | Confirm the exact installed input module and terminal allocation. Verify X0–X7 against the physical module and GX Works2 project. | [ ] | ______ / ______ |

---

## 3. NETWORK ARCHITECTURE & ADDRESSING VERIFICATION

### 3.1 Network Topology Plan
- **Subnet:** `192.168.3.0/24`
- **Subnet Mask:** `255.255.255.0`
- **Gateway / Switch:** `192.168.3.1`
- **ESP32 Gateway:** `<ESP32-IP>` (Port 80; read the current DHCP address from LCD/Serial Monitor)
- **Station 1 (Q03UDECPU):** `192.168.3.30` (Port 5010, MC Protocol 3E Binary TCP)
- **Station 2 (iQ-R; exact CPU suffix unverified):** `192.168.3.20` (Port 5010, MC Protocol 3E Binary TCP)

### 3.2 Network Reachability Verification Steps

```powershell
# 1. Ping test from Commissioning Laptop
$Esp32Ip = Read-Host 'ESP32 IP shown on LCD/Serial Monitor'
ping $Esp32Ip   # ESP32 Local Gateway
ping 192.168.3.30    # Q03UDECPU PLC
ping 192.168.3.20    # Station 2 iQ-R (provisional)

# 2. Verify PLC MC Protocol Port Accessibility (PowerShell)
Test-NetConnection -ComputerName 192.168.3.30 -Port 5010
Test-NetConnection -ComputerName 192.168.3.20 -Port 5010

# 3. Verify ESP32 Gateway HTTP REST Service
Invoke-RestMethod -Uri "http://$Esp32Ip/api/v1/health"
```

| Step | Target Device | Expected Response | Verified (Y/N) | Latency (ms) |
| :---: | :--- | :--- | :---: | :---: |
| **3.1** | ESP32 Gateway (`<ESP32-IP>`) | TCP port 80 reachable (`Test-NetConnection`); local HMI opens in a phone/laptop browser | [ ] | ______ ms |
| **3.2** | Q03UDECPU (`192.168.3.30:5010`) | TCP port 5010 open, `TcpTestSucceeded: True` | [ ] | ______ ms |
| **3.3** | iQ-R (`192.168.3.20:5010`) | TCP port 5010 open, `TcpTestSucceeded: True` | [ ] | ______ ms |
| **3.4** | ESP32 REST Health API | `HTTP 200 OK`; JSON contains `status: "healthy"` when Wi-Fi is connected and `firmware_version: "2.2.1"` | [ ] | ______ ms |

---

## 4. GATEWAY BOOT & HEADLESS VS LCD VERIFICATION

| Step | Inspection Item | Verification Procedure | Pass Criteria | Status |
| :---: | :--- | :--- | :--- | :---: |
| **4.1** | **Serial Console Output** | Attach USB to ESP32 at 115200 baud. Monitor boot sequence. | No panic, FreeRTOS worker started on Core 0, web server on Core 1. | [ ] |
| **4.2** | **LCD Detection Check** | Query `GET /api/v1/system`. Check `lcd.status` and `lcd.present`. | If physical LCD is detected: `status: ACTIVE` and `present: true`. If absent: `status: NOT_DETECTED` and `present: false`; headless execution continues. | [ ] |
| **4.3** | **LittleFS File Mount** | Confirm Serial Monitor reports `LittleFS mounted successfully`; then open `/`, `/assets/css/style.css`, and `/assets/js/app.js` from the ESP32 origin. | Full HMI loads; CSS and JavaScript return HTTP 200. If the fallback page appears, stop and upload the LittleFS image with `pio run -t uploadfs`. | [ ] |
| **4.4** | **FreeRTOS Worker Health** | Inspect `GET /api/v1/system` worker block. | `core: 0`, `status: RUNNING`, `min_free_stack_bytes > 2048`. | [ ] |

---

## 5. DEFAULT FAIL-CLOSED SAFETY VALIDATION

With the published default configuration, execute the following monitoring-only checks. They verify the default write gates and route behavior; they do not commission physical actuation:

| Step | Security Check | Execution Procedure | Expected Outcome | Pass/Fail |
| :---: | :--- | :--- | :--- | :---: |
| **5.1** | **Default Q-Series Writes** | Query `GET /api/v1/devices` and inspect device `melsec_q03`. | Its `physical_writes_enabled` field must be `false`. | [ ] PASS |
| **5.2** | **Default R-Series Writes** | Query `GET /api/v1/devices` and inspect device `melsec_r04`. | Its `physical_writes_enabled` field must be `false`. | [ ] PASS |
| **5.3** | **Default Q-Series Write Gate** | With `Q_PLC_WRITES_ENABLED = false`, submit a syntactically valid request to `/api/v1/devices/melsec_q03/outputs/Y20/command` with JSON `{"state":1}` and no PIN. | HTTP 403 with `status: PHYSICAL_WRITES_DISABLED`. Firmware gate is checked before PIN validation. Zero PLC write frames sent. | [ ] PASS |
| **5.4** | **Default R-Series Write Gate** | With `R_PLC_WRITES_ENABLED = false`, submit a syntactically valid request to `/api/v1/devices/melsec_r04/outputs/Y20/command` with JSON `{"state":1}`. | HTTP 403 with `status: PHYSICAL_WRITES_DISABLED`. Zero PLC write frames sent. | [ ] PASS |
| **5.5** | **Y0 Route Absence** | Request `/api/v1/devices/melsec_q03/outputs/Y0/command`. No POST handler is registered for Y0. | HTTP 404; no command handler and no PLC write frame. The driver-level Y0 rejection is also covered by automated tests. | [ ] PASS |
| **5.6** | **Frontend Point List** | Inspect the Station 1 output selector in the live ESP32 HMI. | Y20–Y27 appear as separate points; Y0 is absent. | [ ] PASS |
| **5.7** | **Frontend UI Status** | Open `http://<ESP32-IP>/` in browser using the current address shown by the ESP32. Observe Station 1 and Station 2 banners. | Station 1: `MONITORING AVAILABLE — CONTROL LOCKED`. Station 2: `REACHABLE — CONFIGURATION UNVERIFIED`. | [ ] PASS |

---

## 6. STATION 1 (Q03UDECPU) TELEMETRY COMMISSIONING

Verify that all 8 physical inputs (X0–X7) and 8 physical outputs (Y20–Y27) are accurately read from PLC device memory via MC Protocol 3E Binary TCP:

### 6.1 Input Telemetry Verification (X0–X7)
Toggle physical input switches on the PLC input rack and verify that the value changes in the web interface and `readings.X0`–`readings.X7` (`raw_value`) from `/api/v1/devices/melsec_q03/telemetry` within the configured polling interval:

| Input Point | Hardware Action | Physical LED | API Value (`readings.X*.raw_value`) | UI Status Grid | Pass/Fail |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **X0** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X1** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X2** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X3** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X4** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X5** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X6** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |
| **X7** | Toggle switch ON -> OFF | ON -> OFF | `1` -> `0` | Active (Green) -> Inactive (Gray) | [ ] |

### 6.2 Output Telemetry Verification (Y20–Y27)
Manually force outputs via GX Works2 or bench test routine to confirm monitoring accuracy:

| Output Point | Device Code | Address (Hex) | Read Value (`outputs.Y*`) | UI Status Chip | Verified |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **Y20** | `0x9D` | `0x000014` | `0` / `1` | `Y20: OFF` / `Y20: ON` | [ ] |
| **Y21** | `0x9D` | `0x000015` | `0` / `1` | `Y21: OFF` / `Y21: ON` | [ ] |
| **Y22** | `0x9D` | `0x000016` | `0` / `1` | `Y22: OFF` / `Y22: ON` | [ ] |
| **Y23** | `0x9D` | `0x000017` | `0` / `1` | `Y23: OFF` / `Y23: ON` | [ ] |
| **Y24** | `0x9D` | `0x000018` | `0` / `1` | `Y24: OFF` / `Y24: ON` | [ ] |
| **Y25** | `0x9D` | `0x000019` | `0` / `1` | `Y25: OFF` / `Y25: ON` | [ ] |
| **Y26** | `0x9D` | `0x00001A` | `0` / `1` | `Y26: OFF` / `Y26: ON` | [ ] |
| **Y27** | `0x9D` | `0x00001B` | `0` / `1` | `Y27: OFF` / `Y27: ON` | [ ] |

---

## 7. PHYSICAL WRITE ENABLING PROCEDURE (STATION 1 — Q-SERIES ONLY)

Execute this step ONLY after Sections 2 through 6 are fully satisfied and signed off by the Lead Automation Engineer.

### Step 7.1: Physical Area Clearance & E-Stop Verification
- [ ] Ensure all machinery connected to output module is mechanically isolated or locked out.
- [ ] Have a qualified person verify the actual machine emergency-stop and energy-isolation functions against the approved machine risk assessment and electrical drawings. Do not rely on this dashboard as a safety function.
- [ ] Safety Sign-Off Signature: _______________________ Date: ______________

### Step 7.2: Firmware Configuration Modification
In file `firmware/esp32_local_gateway/src/config.h`:
```c
// Enable physical writes for Station 1 (Q-Series)
#define Q_PLC_WRITES_ENABLED true

// Station 2 MUST remain false
#define R_PLC_WRITES_ENABLED false
```

### Step 7.3: Provision Commissioning Operator PIN
In file `firmware/esp32_local_gateway/src/secrets.h`:
```c
// Provision only after the physical write gate and safety checklist have been approved.
#define SECRET_OPERATOR_PIN ""
```

### Step 7.4: Compile & Flash Gateway Firmware
```powershell
# Build firmware binary
platformio run -d firmware/esp32_local_gateway

# Flash via USB / UART
platformio run -d firmware/esp32_local_gateway -t upload

# Verify write gates remain DISABLED during the initial monitoring-only test
Invoke-RestMethod -Uri "http://$Esp32Ip/api/v1/system" | Select-Object physical_writes_enabled
Invoke-RestMethod -Uri "http://$Esp32Ip/api/v1/devices" | ConvertTo-Json -Depth 6
# Expected: aggregate physical_writes_enabled is false; both device entries also report false.
```

---

## 8. EIGHT-CHANNEL INDEPENDENT OUTPUT ACTUATION TEST

This section is NOT part of the initial monitoring-only acceptance. Perform it only under a separate, documented machine risk review with an approved isolated test load, verified terminal mapping, hardwired safety devices, the Q-Series write gate deliberately enabled in a dedicated build, and a private PIN provisioned locally. Keep the R-Series write gate disabled. Test individual Q-Series points through the web UI (`http://<ESP32-IP>/`):

### 8.1 Sequential Actuation Matrix
For each channel, command ON then OFF using a safe isolated load. Independently observe the output module/load using a suitable rated instrument. Confirm no other output memory bits or physical test loads change. PLC read-back alone is not proof of contact closure, field voltage, load current or actuator movement.

| Test ID | Point | Command | PIN Entered | Physical Relay / LED | Crosstalk Check (Other 7 Outputs) | Readback Indicator | Pass/Fail |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **8.1.1** | Y20 | ON (1) | Valid | Closed / LIT | Y21–Y27 remain OFF | `Y20: 1 (ON)` | [ ] |
| **8.1.2** | Y20 | OFF (0) | Valid | Open / DARK | Y21–Y27 remain OFF | `Y20: 0 (OFF)` | [ ] |
| **8.2.1** | Y21 | ON (1) | Valid | Closed / LIT | Y20, Y22–Y27 remain OFF | `Y21: 1 (ON)` | [ ] |
| **8.2.2** | Y21 | OFF (0) | Valid | Open / DARK | Y20, Y22–Y27 remain OFF | `Y21: 0 (OFF)` | [ ] |
| **8.3.1** | Y22 | ON (1) | Valid | Closed / LIT | Y20–Y21, Y23–Y27 remain OFF | `Y22: 1 (ON)` | [ ] |
| **8.3.2** | Y22 | OFF (0) | Valid | Open / DARK | Y20–Y21, Y23–Y27 remain OFF | `Y22: 0 (OFF)` | [ ] |
| **8.4.1** | Y23 | ON (1) | Valid | Closed / LIT | Y20–Y22, Y24–Y27 remain OFF | `Y23: 1 (ON)` | [ ] |
| **8.4.2** | Y23 | OFF (0) | Valid | Open / DARK | Y20–Y22, Y24–Y27 remain OFF | `Y23: 0 (OFF)` | [ ] |
| **8.5.1** | Y24 | ON (1) | Valid | Closed / LIT | Y20–Y23, Y25–Y27 remain OFF | `Y24: 1 (ON)` | [ ] |
| **8.5.2** | Y24 | OFF (0) | Valid | Open / DARK | Y20–Y23, Y25–Y27 remain OFF | `Y24: 0 (OFF)` | [ ] |
| **8.6.1** | Y25 | ON (1) | Valid | Closed / LIT | Y20–Y24, Y26–Y27 remain OFF | `Y25: 1 (ON)` | [ ] |
| **8.6.2** | Y25 | OFF (0) | Valid | Open / DARK | Y20–Y24, Y26–Y27 remain OFF | `Y25: 0 (OFF)` | [ ] |
| **8.7.1** | Y26 | ON (1) | Valid | Closed / LIT | Y20–Y25, Y27 remain OFF | `Y26: 1 (ON)` | [ ] |
| **8.7.2** | Y26 | OFF (0) | Valid | Open / DARK | Y20–Y25, Y27 remain OFF | `Y26: 0 (OFF)` | [ ] |
| **8.8.1** | Y27 | ON (1) | Valid | Closed / LIT | Y20–Y26 remain OFF | `Y27: 1 (ON)` | [ ] |
| **8.8.2** | Y27 | OFF (0) | Valid | Open / DARK | Y20–Y26 remain OFF | `Y27: 0 (OFF)` | [ ] |

### 8.2 Banned Point Y0 Re-Verification
- [ ] Inspect UI dropdown: confirm point `Y0` does NOT appear anywhere in the station point selector.
- [ ] Attempt programmatic write via `curl` to `Y0`:
  ```powershell
  # Y0 has no registered command route. This request is a routing check only.
  curl.exe -i -X POST "http://$Esp32Ip/api/v1/devices/melsec_q03/outputs/Y0/command" `
    -H "Content-Type: application/json" `
    -d '{"state":1}'
  # Expected: HTTP 404; no PLC write frame.
  ```
- [ ] Verify HTTP 404 Not Found returned because no Y0 route is registered.
- [ ] Confirm no physical output relay energizes.

---

## 9. STATION 2 (iQ-R; exact CPU suffix unverified) PROVISIONAL MONITORING CHECK

| Step | Item | Procedure | Expected Result | Pass/Fail |
| :---: | :--- | :--- | :--- | :---: |
| **9.1** | **R-Series Polling** | Monitor Core 0 poll cycle for the provisional Station 2 endpoint (`192.168.3.20:5010`). | A reachable TCP port alone is not acceptance. Confirm successful MC/SLMP reads and point/device codes against the exact CPU and GX Works3 project. | [ ] |
| **9.2** | **Telemetry Display** | Select Station 2 in Web UI. | Displayed provisional X/Y bit states match the physical rack and GX Works3 project. Until checked, status must remain configuration-unverified; do not enable writes. | [ ] |
| **9.3** | **Unverified Status** | Inspect Station 2 header badge. | Displays: `REACHABLE — CONFIGURATION UNVERIFIED`. | [ ] |
| **9.4** | **Output Lockout** | Verify Output Control panel when Station 2 is selected. | Station 2 control points locked. Actuation button disabled. Dropdown shows lock notice. | [ ] |

---

## 10. FAULT RECOVERY & INCIDENT PROCEDURES

| Fault Scenario | Diagnostic Indicator | Automated Response | Operator Action |
| :--- | :--- | :--- | :--- |
| **PLC Disconnected / Powered Off** | Web UI shows Station `OFFLINE`. Gateway log: `TCP connect timeout (1000ms)`. | Core 0 poll worker marks station down, sets error flag. Web server continues serving UI smoothly (<2ms response). | Check PLC power, Ethernet switch port, and IP configuration. Restoring connection clears fault automatically. |
| **Invalid PIN Rate-Limiting Lockout** | HTTP 429 Too Many Requests (`AUTH_RATE_LIMITED`). | Gateway locks actuation API for 30 seconds after 5 failed PIN attempts. | Wait 30 seconds. Verify PIN before re-submitting. |
| **FreeRTOS Worker Watchdog Reset** | ESP32 reboots, serial reports `WDT trigger on Core 0`. | ESP32 hardware watchdog reboots system in < 500ms. Defaults to fail-closed. | Verify network switch latency and ensure PLC is responding within 1000ms timeout. |
| **Emergency Cabinet Shutdown** | Physical E-Stop button pressed. | 24V supply to output relays immediately drops. Relays open instantly. | Investigate cause of emergency. Clear safety zone before resetting E-Stop. |

---

## 11. COMMISSIONING SIGN-OFF & HANDOVER APPROVAL

| Role | Name | Signature | Date |
| :--- | :--- | :--- | :--- |
| **Lead Automation Engineer** | ___________________________ | ___________________________ | ____________ |
| **Electrical Safety Inspector** | ___________________________ | ___________________________ | ____________ |
| **Plant Operations Manager** | ___________________________ | ___________________________ | ____________ |
| **ESP32 Firmware Lead** | ___________________________ | ___________________________ | ____________ |

> [!NOTE]
> Keep a signed physical copy of this document inside the control cabinet enclosure `ENC-PLC-01`. Keep an electronic copy alongside the project handover archive `PROJECT_V2_2_1_HANDOVER.zip`.
