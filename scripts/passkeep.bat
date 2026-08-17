@echo off
setlocal enabledelayedexpansion
title PassKeep - Flutter Runner Tool
color 0A

:menu
cls
echo ========================================================
echo              PASSKEEP - FLUTTER HELPER TOOL             
echo ========================================================
echo.
echo   [1] Debug Mode - Physical Device (USB)
echo   [2] Debug Mode - Physical Device (Wireless / Wi-Fi)
echo   [3] Pair Wireless Device (ADB Pair - 1-Time Setup)
echo   [4] Debug Mode - Chrome Browser
echo   [5] Debug Mode - Edge Browser
echo   [6] Build Release APK (Obfuscated) + Open Output Folder
echo   [7] Exit
echo.
echo ========================================================
echo   Debug Mode Controls:
echo   - Press 'r' in terminal for HOT RELOAD
echo   - Press 'R' in terminal for HOT RESTART
echo ========================================================
echo.
set /p choice="Select an option (1-7): "

if "!choice!"=="1" goto debug_usb
if "!choice!"=="2" goto debug_wireless
if "!choice!"=="3" goto adb_pair
if "!choice!"=="4" goto debug_chrome
if "!choice!"=="5" goto debug_edge
if "!choice!"=="6" goto build_release
if "!choice!"=="7" goto exit

echo.
echo Invalid option! Please try again.
timeout /t 2 >nul
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