@echo off
title Photon Shooter Lambda - Godot 4.7.2 Edition
set "GODOT_EXE=C:\Users\Chris\Documents\antigravity\wonderful-curie\tools\godot\Godot_v4.7.2-stable_win64.exe"
set "PROJECT_PATH=%~dp0PhotonShooter_Godot"

if not exist "%GODOT_EXE%" (
    echo [ERROR] Could not find Godot 4.7.2 executable at:
    echo   "%GODOT_EXE%"
    pause
    exit /b 1
)

echo Launching Photon Shooter Lambda (Godot 4.7.2 Edition)...
start "" "%GODOT_EXE%" --path "%PROJECT_PATH%"
