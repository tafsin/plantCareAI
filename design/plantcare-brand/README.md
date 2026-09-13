# PlantCare AI brand assets

## Masters

- `masters/app-icon-master.png`: full-bleed opaque square icon master.
- `masters/brand-mark-transparent.png`: transparent leaf/circuit mark.
- `masters/wordmark-horizontal.png`: transparent horizontal website wordmark.

## Platform assets

- `android/play-store-icon-512.png`: Google Play listing icon.
- `android/adaptive-foreground-1024.png`: Android adaptive-icon foreground master. Use `#F5FAF2` as the background color.
- `ios/AppIcon-1024.png`: opaque iOS App Store icon master.
- `web/favicon-16.png`, `favicon-32.png`, `favicon-48.png`: browser favicons.
- `web/icons/Icon-192.png`, `Icon-512.png`: Flutter web/PWA icons.
- `web/icons/Icon-maskable-192.png`, `Icon-maskable-512.png`: Flutter web maskable icons.
- `splash/splash-mark-512.png`: transparent splash-screen mark.

The horizontal wordmark should be used directly from `masters/wordmark-horizontal.png` in web headers and authentication screens.

## Brand direction

The logo combines a healthy green leaf with white circuit-node veins to represent plant care and AI. The primary palette is forest green, emerald, lime, pale mint, and deep charcoal.

## Integration note

Keep the master files in source control and generate platform-specific launcher assets from them. Do not add rounded corners to the iOS or Android source icon; the operating system applies its own mask.
