# App Icon Setup Instructions

## Option 1: Use Online Icon Generator (Easiest)

1. Go to https://icon.kitchen/ or https://appicon.co/
2. Upload a cricket-themed image (cricket ball, bat, or stumps)
3. Set background color to: #1a1a2e (dark blue)
4. Set foreground color to: #ff6b35 (orange)
5. Download the generated icons
6. Extract and copy:
   - `app_icon.png` to `assets/icon/app_icon.png`
   - `app_icon_foreground.png` to `assets/icon/app_icon_foreground.png`

## Option 2: Use Existing Icon

If you have a 1024x1024 PNG image:
1. Place it at `assets/icon/app_icon.png`
2. Create a foreground version (transparent background) at `assets/icon/app_icon_foreground.png`

## Option 3: Use Default Flutter Icon (Temporary)

Remove the flutter_launcher_icons configuration from pubspec.yaml and use the default Flutter icon.

## After Adding Icons

Run these commands:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

This will generate all the required icon sizes for Android and iOS.

## Quick Test Icon

For a quick test, you can use any 1024x1024 PNG image as `assets/icon/app_icon.png`.
The app will use it as the icon after running the flutter_launcher_icons command.

## Current Configuration

The app is configured to use:
- Main icon: assets/icon/app_icon.png
- Adaptive icon background: #1a1a2e (dark blue)
- Adaptive icon foreground: assets/icon/app_icon_foreground.png

## Colors Used in App
- Primary: #1a1a2e (dark blue)
- Accent: #ff6b35 (orange)
- Background: #0f0f1e (very dark blue)

Use these colors for a consistent look!
