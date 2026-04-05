@echo off
echo 🏏 Building Cricket Ultimate Manager APK...
echo.

echo 📦 Step 1: Cleaning previous builds...
call flutter clean

echo.
echo 📥 Step 2: Getting dependencies...
call flutter pub get

echo.
echo 🔨 Step 3: Building release APK...
call flutter build apk --release

echo.
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ APK built successfully!
    echo.
    echo 📍 Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo 📊 APK Details:
    for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do (
        echo    Size: %%~zA bytes
    )
    echo.
    echo 💡 To install on device:
    echo    adb install build\app\outputs\flutter-apk\app-release.apk
) else (
    echo ❌ Build failed! Check the output above for errors.
)

echo.
pause
