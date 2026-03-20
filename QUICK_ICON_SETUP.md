# Quick App Icon Setup

## Easiest Method (No image needed)

1. **Install ImageMagick** (if not already installed):
   - Download from: https://imagemagick.org/script/download.php#windows
   - Or use: `winget install ImageMagick.ImageMagick`

2. **Generate icon from SVG**:
   ```bash
   magick assets/icon/app_icon.svg -resize 1024x1024 assets/icon/app_icon.png
   magick assets/icon/app_icon.svg -resize 1024x1024 assets/icon/app_icon_foreground.png
   ```

3. **Generate launcher icons**:
   ```bash
   flutter pub get
   flutter pub run flutter_launcher_icons
   ```

## Alternative: Use Online Converter

1. Go to https://cloudconvert.com/svg-to-png
2. Upload `assets/icon/app_icon.svg`
3. Set size to 1024x1024
4. Download and save as `assets/icon/app_icon.png`
5. Copy the same file to `assets/icon/app_icon_foreground.png`
6. Run: `flutter pub get && flutter pub run flutter_launcher_icons`

## Skip Icon Setup (Use Default)

If you want to skip this for now, remove these lines from `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#1a1a2e"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

Then just build the APK with the default Flutter icon.
