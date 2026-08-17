@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0\.."
title PassKeep - Flutter Runner Tool
color 0A

:menu
cls
echo ========================================================
echo              PASSKEEP - FLUTTER HELPER TOOL             
echo ========================================================
echo.
echo   [1] Fast Debug (Attach Mode - Instant / No Rebuild)
echo   [2] Debug Mode - Physical Device (USB / Full Build)
echo   [3] Debug Mode - Physical Device (Wireless / Wi-Fi)
echo   [4] Pair Wireless Device (ADB Pair - 1-Time Setup)
echo   [5] Debug Mode - Chrome Browser
echo   [6] Debug Mode - Edge Browser
echo   [7] Build Release APK (Obfuscated) + Open Output Folder
echo   [8] Exit
echo.
echo ========================================================
echo   Debug / Attach Mode Controls:
echo   - Press 'r' in terminal for HOT RELOAD
echo   - Press 'R' in terminal for HOT RESTART
echo   - Press 'q' in terminal to QUIT / DETACH
echo ========================================================
echo.
set /p choice="Select an option (1-8): "

if "!choice!"=="1" goto fast_attach
if "!choice!"=="2" goto debug_usb
if "!choice!"=="3" goto debug_wireless
if "!choice!"=="4" goto adb_pair
if "!choice!"=="5" goto debug_chrome
if "!choice!"=="6" goto debug_edge
if "!choice!"=="7" goto build_release
if "!choice!"=="8" goto exit

echo.
echo Invalid option! Please try again.
timeout /t 2 >nul
goto menu

:fast_attach
cls
echo ========================================================
echo       FAST DEBUG: ATTACH MODE (INSTANT / NO REBUILD)
echo ========================================================
echo.
echo Checking connected devices...
adb devices
echo.
echo 1. Launching PassKeep app on connected device...
adb shell am start -n com.passkeep.passkeep/.MainActivity >nul 2>&1
echo 2. Attaching Flutter debugger to running instance...
echo.
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit / Detach
echo.
flutter attach --device-timeout 10
pause
goto menu

:debug_usb
cls
echo ========================================================
echo         RUNNING DEBUG MODE: USB PHYSICAL DEVICE
echo ========================================================
echo.
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit
echo.
flutter run
pause
goto menu

:debug_wireless
cls
echo ========================================================
echo      RUNNING DEBUG MODE: WIRELESS PHYSICAL DEVICE
echo ========================================================
echo.
echo Checking currently connected ADB devices...
echo --------------------------------------------------------
adb devices
echo --------------------------------------------------------
echo.
set /p conn_choice="Do you need to connect a new Wireless IP:PORT? (Y/N): "
if /i "!conn_choice!"=="Y" (
    echo.
    echo Open Settings ^> Developer Options ^> Wireless Debugging on your phone.
    set /p target_ip="Enter current IP:PORT shown on your phone screen: "
    adb connect !target_ip!
    echo.
)
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit
echo.
flutter run
pause
goto menu

:adb_pair
cls
echo ========================================================
echo             ADB WIRELESS PAIRING (1-TIME SETUP)
echo ========================================================
echo.
echo On your phone: Settings ^> Developer Options ^> Wireless Debugging ^> Pair device with pairing code
echo.
set /p pair_ip="Enter Pairing IP:PORT shown on phone: "
adb pair !pair_ip!
echo.
pause
goto menu

:debug_chrome
cls
echo ========================================================
echo             RUNNING DEBUG MODE: CHROME BROWSER
echo ========================================================
echo.
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit
echo.
flutter run -d chrome
pause
goto menu

:debug_edge
cls
echo ========================================================
echo              RUNNING DEBUG MODE: EDGE BROWSER
echo ========================================================
echo.
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit
echo.
flutter run -d edge
pause
goto menu

:build_release
cls
echo ========================================================
echo     BUILDING FULL OBFUSCATED RELEASE APK (PassKeep)...
echo ========================================================
echo.
flutter build apk --release --obfuscate --split-debug-info=./build/app/outputs/symbols
if !ERRORLEVEL! EQU 0 (
    echo.
    echo ========================================================
    echo SUCCESS! Opening APK output folder...
    echo ========================================================
    start "" "%CD%\build\app\outputs\flutter-apk"
) else (
    echo.
    echo ========================================================
    echo ERROR: Failed to build release APK.
    echo ========================================================
)
pause
goto menu

:exit
exit