'use strict';

const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');

const root = path.resolve(__dirname, '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');

const webServer = read('firmware/esp32_local_gateway/src/web_server.cpp');
const config = read('firmware/esp32_local_gateway/src/config.h');
const exampleSecrets = read('firmware/esp32_local_gateway/src/secrets.example.h');
const legacyAgent = read('agent/service.py');

assert.doesNotMatch(webServer, /Access-Control-Allow-Origin\s*[",]/,
  'ESP32 must not grant wildcard or permissive cross-origin access');
assert.doesNotMatch(webServer, /Access-Control-Allow-Private-Network/,
  'ESP32 must not opt into cross-origin Private Network Access');
assert.match(webServer, /server\.send\(403,\s*"application\/json"/,
  'unsupported OPTIONS preflight must be rejected');
assert.match(config, /#define\s+Q_PLC_WRITES_ENABLED\s+false/,
  'Q-Series physical writes must default to disabled');
assert.match(config, /#define\s+R_PLC_WRITES_ENABLED\s+false/,
  'R-Series physical writes must default to disabled');
assert.match(exampleSecrets, /#define\s+SECRET_OPERATOR_PIN\s+""/,
  'example operator PIN must be blank');
assert.match(legacyAgent, /device_env\s*=\s*\"LEGACY_Q_PLC\"\s+if\s+clean_dev\s*==\s*\"melsec_q03\"\s+else\s+\"LEGACY_R_PLC\"/,
  'legacy hardware gate must use distinct Q- and R-Series environment names');
assert.match(legacyAgent, /gate_name\s*=\s*f\"\{device_env\}_WRITES_ENABLED\"/,
  'legacy physical write must require an explicit per-PLC environment flag');
assert.match(legacyAgent, /os\.getenv\(gate_name,\s*\"false\"\)/,
  'legacy physical write must be disabled when the environment flag is absent');
assert.doesNotMatch(legacyAgent, /(?:PIN|pin)\s*[:=]\s*["']1234["']/,
  'legacy agent must not contain a default operator PIN');

console.log('[Firmware security contract] 10 PASS, 0 FAIL');
