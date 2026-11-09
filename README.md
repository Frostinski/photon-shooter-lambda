# Photon Shooter Lambda (PSL)
**Charity Day (11th November) — Godot 4.7.2 Edition**

A side-scrolling 2.5D arcade space shooter built in **Godot 4.7.2** (Forward+ / GDScript) featuring real-time 3D Meshy + Blender spacecraft, dynamic Blue Giant solar self-shadowing and live weapon hull reflections, full gamepad + keyboard/mouse support, and a persistent charity tournament leaderboard.

---

## Key Features

- **Real-Time 3D Spacecraft & Dynamic Cosmic Lighting**:
  - 3D player starfighter and enemy fleet (`Scout`, `Interceptor`, `Destroyer`, and `Omega Titan Dreadnought`) rendered via isolated `SubViewport` rigs with continuous aerodynamic banking and procedural turbulent thruster shaders.
  - Procedural FBM nebula, twinkling starfield, and distant Blue Giant star (`space_backdrop.gdshader`) driving directional 3D hull shadows, rim highlights, and real-time `OmniLight3D` laser/torpedo reflections.
- **Minimal Diegetic Combat HUD**:
  - Clean, unobstructed widescreen arena with only a minimal score box at the top right.
  - **Twin Wing Photon Plasma Lances** (primary fire) and **3-Charge Homing Photon Torpedoes** (secondary fire, shown on the compact under-ship pod).
  - **Phase Barrel-Roll Dodge**: twin 3D thruster plumes shift from **Thermal Amber-Orange** while recharging back to **Charged Electric Cyan-Blue** accompanied by a subtle audio chime when dodge is ready.
  - **Directional Hexagonal Deflector Shield**: floats a compact 3-cell shield bar above the starfighter on impact that smoothly fades out; turns **crimson-red** on the 3rd shield hit when the last shield is lost.
- **Multi-Phase Campaign, 3D Asteroid Hazards & Enraged Capital Bosses**:
  - Tumbling 3D cratered basalt **Large & Small Asteroids** across Phases `1–3` (tough Large boulders split into `2` Small fragments; Small fragments award `+100` bonus points).
  - 4 escalating combat waves culminating in the **Destroyer** and **Omega Titan Dreadnought** (contoured multi-zone hull hitboxes, 50% HP invulnerable **Emergency Shield** energy-overload barrage with high-speed player-targeted lasers, and accelerated Phase 2 firing patterns).
- **Interactive Flight Training & Charity Leaderboard**:
  - Streamlined 4-step live flight training sequence before launch (skippable anytime).
  - Persistent top-10 arcade high-score table (`user://high_scores.json` in standalone builds, `PhotonShooter_Godot/data/high_scores.json` in editor runs).

---

## Controls

| Action | Gamepad (Xbox / PlayStation) | Keyboard / Mouse |
| :--- | :--- | :--- |
| **Move Ship / Navigate Menu** | Left Stick / D-Pad | `W`, `A`, `S`, `D` or Arrow Keys |
| **Primary Fire (Photon Lances)** | `A` / `Cross` or `RT` | **Left Mouse Button** (or `Z` / `J`) |
| **Secondary Fire (Homing Torpedo)** | `X` / `Square` | **Right Mouse Button** (or `X` / `K`) |
| **Phase Barrel-Roll Dodge** | `LT` / `LB` / `RB` | **Space Bar** (or `Left Shift` / `C`) |
| **Menu Select / Confirm** | `A` / `Start` | `Enter` / `Left Click` / `Space` |
| **Pause / In-Game Menu** | `Start` / `Options` | `Escape` / `P` |
| **Toggle Fullscreen** | — | `F11` or `Alt + Enter` |

---

## Running the Game

### Option 1: Standalone Windows Application (No Godot Required)
Every push to `master` / `main` automatically builds standalone single-file Windows executables via GitHub Actions (`.github/workflows/build-windows.yml`) and publishes them under [**GitHub Releases (`latest`)**](https://github.com/Frostinski/photon-shooter-lambda/releases):
- **`PhotonShooterLambda-Windows-x86_64.zip`** — Intel / AMD Surface Pros and standard 64-bit Windows 10/11 PCs.
- **`PhotonShooterLambda-Windows-arm64.zip`** — Native ARM64 build for Snapdragon X (Copilot+) Surface Pros.

Extract the `.zip` and double-click the `.exe` to play directly with nothing installed.

### Option 2: From Source with Godot 4.7.2
Double-click **`Launch_PhotonShooter_Godot.bat`** to start the game directly, or **`Open_PhotonShooter_In_Godot_Editor.bat`** to open the project in the Godot 4.7.2 Editor.

### Command Line
```powershell
Godot_v4.7.2-stable_win64.exe --path PhotonShooter_Godot
```

### Automated Verification Suite
```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path PhotonShooter_Godot --script res://tests/test_godot_port.gd
```

---

## Project Layout

- `PhotonShooter_Godot/` — Complete Godot 4.7.2 project (`project.godot`, `scenes/`, `scripts/`, `assets/`, `data/`, `tests/`).
- `scripts/` — Optional Meshy.ai + headless Blender 5.x 3D spacecraft asset generation and processing pipeline scripts (reads `MESHY_API_KEY` from `.env`).
