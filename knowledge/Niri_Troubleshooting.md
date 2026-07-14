# Niri Troubleshooting

### AyuGram / Telegram Desktop Rendering Issues (Jagged Fonts & Avatars)
**Symptom**: Avatars have sharp corners instead of smooth circles, and fonts lack antialiasing (jagged edges) in Niri, whereas they look fine in Hyprland.
**Cause**: Niri's fractional or integer scaling (e.g., `scale 2.5` or `scale 2`) interferes with the app's rendering. Niri's downscaling or XWayland upscaling breaks the antialiasing and subpixel rendering for Qt apps.
**Solution**: 
1. Open Niri config (`config.kdl`).
2. Ensure the monitor output `scale` is set strictly to `1`:
   ```kdl
   output "HDMI-A-1" {
       mode "2400x1080"
       scale 1
   }
   ```
3. If UI elements are too small at scale 1, adjust the internal interface scale directly within AyuGram (Settings -> Advanced -> Default interface scale).
