# Network Configuration — V2.2.1 Dual-PLC Local Supervisory System

## 1. Operating principle

The primary system is a local LAN application. The ESP32 connects to the TP-Link router **RUBY** over 2.4 GHz Wi-Fi, serves the HMI at HTTP port 80, and communicates directly with the PLCs over TCP. The phone/laptop and ESP32 must be on the same reachable LAN. No cloud broker, PC gateway, port forwarding, or internet connection is required for local operation.

GitHub Pages is an optional public launcher. It requires an internet path to load, then navigates the browser to the ESP32's private LAN address. When the phone is already connected to RUBY, the ESP32 HMI remains available even if internet is unavailable.

## 2. Address register

| Node | Current project address | Port | Status / notes |
|---|---|---:|---|
| RUBY router | `192.168.3.1/24` | Router-managed | Reported project configuration; confirm on router |
| Q-Series PLC | `192.168.3.30` | `5010/TCP` | Q03UDECPU; current working address supplied for this project; confirm in GX Works2 and test TCP reachability |
| R-Series PLC | `192.168.3.20` | `5010/TCP` | Provisional; exact CPU suffix, Ethernet parameters, port and I/O map must be verified on the physical rack/GX Works3 |
| ESP32 gateway | DHCP on `192.168.3.0/24` | `80/TCP` | Read the actual address from the LCD/Serial Monitor or router DHCP lease. Do not assume `.238` or `.50` |
| Mobile / laptop client | DHCP on RUBY | Browser | Must be able to reach the ESP32 and PLC LAN nodes |

The subnet mask used in the reported design is `255.255.255.0`. The router's DHCP pool and reservations are not confirmed by this release. Before testing, ensure the PLC static addresses are outside the active DHCP pool or reserved to prevent duplicate IP conflicts.

## 3. Physical connections

- Connect the Q-Series and iQ-R PLC Ethernet interfaces to RUBY LAN ports or to a switch connected to RUBY's LAN.
- Connect the ESP32 to the same RUBY Wi-Fi network (2.4 GHz).
- Connect the friend/operator phone to the same RUBY Wi-Fi network.
- AP/client isolation must be disabled when it prevents Wi-Fi clients from reaching LAN devices.
- Confirm all devices are in the same intended subnet/VLAN. Guest Wi-Fi networks commonly isolate clients and should not be used for commissioning.

## 4. Internet and router isolation

The RUBY WAN connection is optional. It may be connected when the operator needs to load GitHub Pages or download project material, but local HMI operation must not depend on WAN access. If the router has internet connectivity, maintain firewall protections and **do not create port-forwarding rules** to the ESP32 or either PLC. Never expose PLC TCP port 5010 or the ESP32 HTTP port 80 to the public internet.

For a fully offline bench session, leave WAN disconnected and open `http://<ESP32-IP>/` directly from a phone/laptop connected to RUBY.

## 5. Commissioning network checks

From a laptop connected to RUBY, run PowerShell commands after confirming the addresses:

```powershell
ipconfig
Test-NetConnection -ComputerName 192.168.3.1 -Port 80
Test-NetConnection -ComputerName 192.168.3.30 -Port 5010
Test-NetConnection -ComputerName 192.168.3.20 -Port 5010
```

The R-Series check is provisional until its actual IP/port is verified. To test the ESP32, replace the variable below with the address displayed by the board:

```powershell
$Esp32Ip = Read-Host 'Enter the ESP32 IP shown on the LCD/Serial Monitor'
Test-NetConnection -ComputerName $Esp32Ip -Port 80
Invoke-RestMethod -Uri "http://$Esp32Ip/api/v1/health"
```

A successful TCP test only proves that a port is reachable. It does not prove the MC Protocol frame settings, PLC device addresses, installed I/O mapping, or physical actuator wiring are correct.

## 6. PLC I/O scope and safety

- Q-Series: monitor `X0–X7`; the current prototype presents `Y20–Y27` as eight independent output points. Do not assume an `X3 → Y20` ladder relationship.
- `Y0` is prohibited and must not be used.
- R-Series map `X0–X7` / `Y20–Y27` is provisional only. Do not enable R-Series writes until the CPU model, installed I/O modules, device map and logic have been verified.
- Q and R physical write gates remain disabled by default. Keep them disabled during initial connectivity and monitoring tests.
- PLC memory-bit readback is not proof of field voltage, load current, contactor state or actuator movement. Verify physical outputs using safe, independent instruments and appropriate isolation.

## 7. ESP32 address stability

The current firmware uses DHCP. During commissioning, note the actual lease and, if the router supports it, create a reservation for the ESP32 MAC address only after confirming that the selected address is unused and outside conflicts. The historic `.238` and earlier `.50` values are examples from prior notes, not guaranteed assignments.
