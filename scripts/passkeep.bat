@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0\.."
title PassKeep - Flutter Runner Tool
color 0A

:: Auto-detect compatible Java Runtime (Android Studio JBR or JDK)
if exist "C:\Program Files\Android\Android Studio\jbr\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
    set "PATH=C:\Program Files\Android\Android Studio\jbr\bin;!PATH!"
) else if exist "%LOCALAPPDATA%\Android\Sdk\jbr\bin\java.exe" (
    set "JAVA_HOME=%LOCALAPPDATA%\Android\Sdk\jbr"
    set "PATH=%LOCALAPPDATA%\Android\Sdk\jbr\bin;!PATH!"
) else if exist "C:\Program Files\Java\jdk-22\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Java\jdk-22"
    set "PATH=C:\Program Files\Java\jdk-22\bin;!PATH!"
) else if exist "C:\Program Files\Java\jdk-21\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Java\jdk-21"
    set "PATH=C:\Program Files\Java\jdk-21\bin;!PATH!"
) else if exist "C:\Program Files\Java\jdk-17\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Java\jdk-17"
    set "PATH=C:\Program Files\Java\jdk-17\bin;!PATH!"
)

:menu
cls
echo ========================================================
echo             PASSKEEP - FLUTTER HELPER TOOL             
echo ========================================================
echo.
echo   [1] Fast Debug (Attach Mode - Instant / No Rebuild)
echo   [2] Debug Mode - Physical Device (USB / Full Build)
echo   [3] Debug Mode - Physical Device (Wireless Wi-Fi)
echo   [4] Pair Wireless Device (ADB Pair - 1-Time Setup)
echo   [5] Build and Install Release APK on Connected Phone
echo   [6] Exit
echo.
echo ========================================================
echo   Debug / Attach Mode Controls:
echo   - Press 'r' in terminal for HOT RELOAD
echo   - Press 'R' in terminal for HOT RESTART
echo   - Press 'q' in terminal to QUIT / DETACH
echo ========================================================
echo.
set /p choice="Select an option (1-6): "

if "!choice!"=="1" goto fast_attach
if "!choice!"=="2" goto debug_usb
if "!choice!"=="3" goto debug_wireless
if "!choice!"=="4" goto adb_pair
if "!choice!"=="5" goto build_release
if "!choice!"=="6" goto exit

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
echo        RUNNING DEBUG MODE: USB PHYSICAL DEVICE
echo ========================================================
echo.
if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo [INFO] Debug APK not found. Building via Flutter...
    call flutter build apk --debug
    if !ERRORLEVEL! NEQ 0 (
        echo.
        echo [ERROR] Flutter debug APK build failed!
        pause
        goto menu
    )
) else (
    echo [INFO] Found pre-built Debug APK: build\app\outputs\flutter-apk\app-debug.apk
)
echo.
echo Installing Debug APK to USB connected device...
adb install -r build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Launching PassKeep MainActivity...
adb shell am start -n com.passkeep.passkeep/.MainActivity
echo.
echo Attaching Flutter Debugger...
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit / Detach
echo.
flutter attach
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
echo.
if not exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo [INFO] Debug APK not found. Building via Flutter...
    call flutter build apk --debug
    if !ERRORLEVEL! NEQ 0 (
        echo.
        echo [ERROR] Flutter debug APK build failed!
        pause
        goto menu
    )
) else (
    echo [INFO] Found pre-built Debug APK: build\app\outputs\flutter-apk\app-debug.apk
)
echo.
echo Installing Debug APK to wireless connected device...
adb install -r build\app\outputs\flutter-apk\app-debug.apk
echo.
echo Launching PassKeep MainActivity...
adb shell am start -n com.passkeep.passkeep/.MainActivity
echo.
echo Attaching Flutter Debugger...
echo Controls: [r] Hot Reload ^| [R] Hot Restart ^| [q] Quit / Detach
echo.
flutter attach
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

:build_release
cls
echo ========================================================
echo     BUILDING FULL OBFUSCATED RELEASE APK (PassKeep)...
echo ========================================================
echo.
call flutter build apk --release --obfuscate --split-debug-info=./build/app/outputs/symbols
if !ERRORLEVEL! EQU 0 (
    echo.
    echo ========================================================
    echo [INFO] Build Successful! Installing Release APK to phone...
    echo ========================================================
    adb install -r build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo [INFO] Launching Release App...
    adb shell am start -n com.passkeep.passkeep/.MainActivity
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