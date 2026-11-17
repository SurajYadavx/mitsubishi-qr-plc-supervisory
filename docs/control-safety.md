# Control Safety Architecture — V2.2.1
## Fail-Closed Output Gates, Operator PIN, and PLC Memory Read-Back

## 1. Safety scope

This project is a supervisory prototype, not a safety-rated controller and not a replacement for hardwired emergency stops, safety relays, guards, or the machine risk assessment. The software write gate is an additional barrier, not the machine's safety function.

The V2.2.1 defaults are deliberately monitoring-only:

- `Q_PLC_WRITES_ENABLED` is `false`.
- `R_PLC_WRITES_ENABLED` is `false`.
- `SECRET_OPERATOR_PIN` is empty in the public example and fallback configuration.
- Station 1 Q-Series output points `Y20` through `Y27` are the independent point candidates defined in the firmware allowlist; `Y0` is prohibited.
- Station 2 iQ-R output writes remain locked until its exact CPU, installed I/O modules, Ethernet settings, device addressing and active GX Works3 project have been physically verified.

Do not change these defaults for the first lab visit. First prove power, network, controller identity, telemetry and status reporting.

## 2. Firmware write-validation order

The ESP32 registers explicit `POST` routes for Q-Series and R-Series `Y20`–`Y27`. No route is registered for `Y0`. For a registered command, the firmware validates the JSON `state` as numeric integer `0` or `1`, then calls the PLC manager. The manager's relevant fail-closed order is:

1. Confirm the target device is known.
2. Check that the relevant station write gate is enabled. With the V2.2.1 default (`false`), the request stops here with `PHYSICAL_WRITES_DISABLED`; no PLC write frame is sent.
3. Reject `Y0` and its zero-padded forms.
4. Reject empty, placeholder or mismatched operator PINs.
5. Validate the station-specific output allowlist.
6. Confirm the target station is enabled, acquire the communication mutex, send the MC Protocol write, check the PLC completion code, then issue a memory read-back.

The HTTP handler maps `PHYSICAL_WRITES_DISABLED` to HTTP `403`, `UNAUTHORIZED` to HTTP `401`, and `FORBIDDEN_POINT` to HTTP `403`. An unregistered `Y0` URI is expected to return HTTP `404` because no handler exists for that path.

**Important:** When the station write gate is false, the result is always the write-disabled response before the PIN and point checks are reached. A default-build API request therefore does not independently prove the PIN or Y0 checks; those are covered by code-level tests and by a separate, controlled engineering test only where formally approved.

## 3. Current fail-closed validation procedure

For the initial lab acceptance, leave the two write gates false and keep `SECRET_OPERATOR_PIN` empty. Confirm:

- `GET /api/v1/system` reports the aggregate `physical_writes_enabled` flag as `false`.
- `GET /api/v1/devices` reports `physical_writes_enabled: false` for both `melsec_q03` and `melsec_r04` individually.
- A syntactically valid command to a registered Q-Series point, such as `POST /api/v1/devices/melsec_q03/outputs/Y20/command`, returns HTTP `403` with status `PHYSICAL_WRITES_DISABLED`.
- The Q-Series `Y0` command URI (`/api/v1/devices/melsec_q03/outputs/Y0/command`) has no registered handler and returns HTTP `404`.
- The dashboard does not offer `Y0` in its output selector.
- No PLC write frames are transmitted during the checks above.

For PIN-specific negative testing, use software/unit tests or an approved isolated engineering setup. Only in a dedicated test configuration with the Q write gate deliberately enabled, a private PIN locally provisioned, and physical output loads isolated may the team verify that a wrong PIN returns `401 UNAUTHORIZED` and that `Y0` is rejected with `403 FORBIDDEN_POINT` (if the test invokes the internal command handler directly). Do not enable the write gate on a connected machine just to make an API test pass.

## 4. Read-back semantics

After an authorised write, the firmware checks the PLC's MC Protocol completion code and reads the PLC output memory bit back. Fields such as `readback_value` and `readback_verified` describe that PLC memory-bit state only.

A successful PLC memory read-back is **not** evidence that field voltage is present, a relay contact physically changed, a contactor pulled in, load current flowed, or an actuator moved. Verify those conditions independently using appropriately rated instruments and safe isolated test loads. The UI must not describe memory-bit verification as proof of physical movement or contact closure.

## 5. Conditions before any physical actuation

Physical actuation is outside the initial monitoring-only release test. Before a deliberate later actuation build is considered, a qualified person and the machine owner must:

1. Verify exact PLC models, output module type, terminal map, point-to-wire mapping, electrical ratings and the loaded PLC logic.
2. Complete a machine risk assessment and identify all possible effects of each Y20–Y27 point.
3. Verify hardwired emergency stop and protective interlocks independently of this gateway.
4. Use a safe, isolated test load and confirm that no hazardous motion or process can occur.
5. Change only the required Q-series gate in a controlled build, provision a unique private PIN locally, and keep the R-series gate false.
6. Test one point at a time, confirming neighboring points do not change and independently observing the physical output/load.
7. Restore the write gate to false after the approved test if the system is returning to monitoring-only service.

Never place Wi-Fi credentials or an operator PIN in Git. `secrets.h` is local-only and must remain untracked. The PIN over the current local HTTP link is an accidental-operation barrier; it does not encrypt the network traffic. Keep the RUBY LAN isolated and do not forward ESP32 or PLC ports to the public internet.
