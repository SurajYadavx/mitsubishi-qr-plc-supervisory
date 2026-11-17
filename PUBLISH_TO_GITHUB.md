# Publish Project V2.2.1 to its own GitHub repository

**Repository:** `SurajYadavx/mitsubishi-qr-plc-supervisory`  
**Visibility:** Public (required for GitHub Free Pages)  
**Existing repository:** `SurajYadavx/mitsubishi-q-plc-app` remains untouched.

## Recommended one-step publish on Windows

1. Download and extract `PROJECT_V2_2_1_PUBLISH_READY.zip` into a new folder.
2. Open PowerShell in that extracted folder.
3. Run:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\publish_v2_2_1.ps1
```

4. Type `PUBLISH` when prompted.

The script checks for credentials and local build artifacts before staging. When GitHub CLI (`gh`) is installed and authenticated (`gh auth login`), the script creates the new **public** repository and pushes the release automatically. If GitHub CLI is not available, it opens GitHub's new-repository page; create a public repository named `mitsubishi-qr-plc-supervisory` with **no README, licence or .gitignore**, then return to PowerShell. The script pushes without force-pushing.

The script will stop if the target repository already exists. This is intentional: it must not overwrite a repository that may contain files or commits.

## Enable GitHub Pages

1. Open the new repository on GitHub.
2. Go to **Settings → Pages → Build and deployment**.
3. Set **Source** to **GitHub Actions**.
4. Open **Actions** and check that `Build ESP32 and Deploy Project V2.2.1 to GitHub Pages` succeeds. The firmware build and LittleFS image build must be green before the deploy job runs.
5. The workflow retains `esp32-v2.2.1-ci-build-output-no-secrets` for 30 days as a compile-validation artifact only. It does not contain the RUBY Wi-Fi password and must not be treated as a lab-ready firmware image. Follow the local flashing steps below instead.
6. The expected URL is `https://surajyadavx.github.io/mitsubishi-qr-plc-supervisory/`.

GitHub's workflow creates the `github-pages` deployment environment if it is not already present. The workflow deploys the static `dist/hosted/` artifact after a generic firmware/filesystem compile check; it does not configure Wi-Fi credentials or flash the ESP32. GitHub's documented Pages flow requires the `pages: write` and `id-token: write` permissions and an upload-pages-artifact → deploy-pages workflow.

## What is actually hosted

The public site is a launcher. It asks for the ESP32's current private LAN IP and performs a user-initiated top-level navigation to `http://<ESP32-IP>/`. The full HMI and PLC API run on the ESP32 on the RUBY LAN. This avoids dependence on browser cross-origin fetch/CORS/Local Network Access permissions for normal dashboard use.

The public launcher needs internet to load. If the friend has no internet connection, they can skip GitHub Pages and open the ESP32 address directly while connected to RUBY.

## Security and hardware caution

- Never commit real `secrets.h`, Wi-Fi credentials, operator PINs, private keys or certificates.
- Keep Q- and R-Series write gates disabled during connectivity and monitoring validation.
- Q-series outputs `Y20–Y27` are separate control points; `Y0` is prohibited.
- R-Series mapping remains provisional and R-Series writes remain locked pending rack/configuration verification.
- Do not configure router port forwarding to either PLC or the ESP32.


## Firmware build and flashing note

GitHub Actions compiles a **generic no-secrets** firmware and LittleFS image so the repository can prove that the source builds without publishing RUBY credentials. The retained Actions artifact is not a ready-to-flash lab image. Before flashing the friend's ESP32, create the ignored `firmware/esp32_local_gateway/src/secrets.h` from `secrets.example.h`, enter the real local RUBY Wi-Fi SSID/password, then run PlatformIO `pio run`, `pio run -t upload`, and `pio run -t uploadfs` from the firmware directory. Keep the operator PIN blank and physical write gates disabled for the first monitoring test. Do not commit or send `secrets.h` through GitHub.
