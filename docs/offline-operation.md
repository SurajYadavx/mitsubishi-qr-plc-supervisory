# Offline Operation — V2.2.1

## Supported local operating path

After firmware and the LittleFS image have been flashed, the ESP32 hosts the full HMI and REST API on the RUBY LAN. Routine monitoring does not require a cloud MQTT broker, GitHub Pages, a Windows gateway or internet access.

The system still depends on local power, the RUBY router/switch, the ESP32, and the PLC Ethernet links. “Offline” means no internet/cloud dependency; it does not mean the system is independent of its local network or power supply.

## Cold-start procedure

1. Power the RUBY router and confirm its LAN is available.
2. Power the Mitsubishi PLCs and the ESP32 using supplies appropriate for each device.
3. Wait for the ESP32 to associate with RUBY.
4. Read the ESP32's current DHCP address from its LCD, Serial Monitor at 115200 baud, or the router's DHCP lease table. The address is dynamic; do not rely on `.155`, `.238`, or any other old example.
5. Connect the phone or laptop to the RUBY network. When the router has no internet uplink, keep the client connected to Wi-Fi rather than switching to cellular data.
6. Open `http://<ESP32-IP>/` directly. The GitHub Pages launcher is optional and requires an internet connection to load on first visit.
7. Check gateway health and the Q-Series and R-Series telemetry separately. A PLC can remain offline while the gateway HMI is still reachable.

## Network isolation and failure handling

- Q-Series and R-Series communication are separate station connections. An offline or unconfigured R-Series station should not be interpreted as proof that the Q-Series is offline, or vice versa.
- The initial field test is monitoring-only. Physical output write gates for both stations are disabled by default.
- R-Series CPU suffix, Ethernet endpoint and I/O map remain provisional until the physical rack and PLC project are checked.
- A PLC memory-bit read-back confirms the value held by the PLC; it does not confirm relay contact state, load current, motor rotation or actuator movement.
- The router must permit traffic between Wi-Fi clients and wired PLC ports. Client/AP isolation or VLAN rules can prevent the ESP32 from reaching the PLCs even when the phone can open the HMI.

## If there is no internet connection

Do not use the public GitHub Pages launcher. Connect the client to RUBY and browse directly to `http://<ESP32-IP>/`. If the phone reports that Wi-Fi has no internet, choose the device-specific option that keeps it connected to RUBY. Labels and controls vary by phone and operating-system version.

## Diagnostic fallback

The older Python gateway and MQTT/ESP8266 components are retained in this repository for historical development and compatibility. They are not required for the V2.2.1 ESP32 local operating path and should not be treated as the production fallback without a separate setup and validation exercise.

## Safety state

Keep physical writes disabled during network bring-up and first monitoring acceptance. Do not enable a write gate until the correct PLC model, device addresses, wiring/terminal mapping, output load, machine risk controls and emergency-stop behavior have been reviewed on the bench. Do not expose the ESP32 or PLC ports through public router port forwarding.
