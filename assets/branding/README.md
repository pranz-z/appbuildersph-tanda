# Android launcher branding

`tanda_icon_1024.png` is the supplied, unchanged 1024 × 1024 RGB source image
(opaque; no alpha channel). It is a source asset, not a Flutter runtime asset.

Regenerate Android resources on Windows, without additional packages:

```powershell
powershell -ExecutionPolicy Bypass -File tool/generate_launcher_icons.ps1
```

Legacy icons retain the whole image at 48/72/96/144/192 pixels. Adaptive icons
use transparent 108/162/216/324/432-pixel foreground layers. The central
medallion is scaled to a 65.25 dp diameter on Android's 108 dp adaptive canvas,
within the 66 dp safe circle, over an orange gradient matching the source.
Android chooses the launcher mask. No monochrome/themed-icon artwork is claimed.

The generator only resamples/masks the supplied artwork; it does not redraw it.
Asset authorship/license is not established by this file.
