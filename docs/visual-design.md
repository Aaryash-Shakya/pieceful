# Visual design

These choices were made by the owner while trying the design prototype. They are locked in as the defaults for the real app. Change them only if the owner asks.

## Choices

- **Colour theme:** Midnight table.
- **Mode:** Auto. The app follows the device's light or dark setting. Both palettes below are required.
- **Accent:** the theme's own amber, not a custom colour.
- **Fonts:** Baloo 2 for titles, numbers and buttons, and Quicksand for body text. Both are Google Fonts under the SIL Open Font License, so they can be bundled in the APK. Quicksand is thin at its regular weight, so body text uses weight 600.
- **Shape:** roundness 20% on the prototype's slider, which gives tighter corners than the original look. Corner radii are about 8 px for buttons and icon buttons, 10 px for cards and panels, 9 px for slots and option tiles, and 14 px for sheets.

## Midnight table palette

| Role | Light | Dark |
|---|---|---|
| Page background | `#e7e9f0` | `#0b1020` |
| Surface | `#f6f7fb` | `#131a2e` |
| Raised surface | `#dbdfea` | `#1c2540` |
| Text | `#141b2d` | `#e9edf7` |
| Muted text | `#566079` | `#8d98b5` |
| Lines | `#c9cfdd` | `#27314f` |
| Accent | `#e2a41f` | `#ffc857` |
| Text on accent | `#2a1d00` | `#2a1d00` |
| Accent shadow | `#a87612` | `#b58712` |
| Table felt | `#223a63` | `#14264a` |
| Board | `#2c4878` | `#1c3463` |

The felt and board are used behind the puzzle in both modes. Light mode keeps the dark navy table.

## Effects defaults

- Snap ring on a join (light) and on a lock (larger), in the accent colour.
- Lift shadow under held pieces.
- Confetti and a short shake of the board (about 0.3 seconds, board only, not the interface) when a puzzle is finished.
- Subtle grain on the felt.
- Ghost image is on by default, at 20% opacity.
- Piece edges at 100% strength: a dark outline about 2.3 px wide at 80% opacity around every piece, so cut lines stay clear.
- Reduce motion is off by default but turns on automatically when the device asks for reduced motion. When on, the ring, confetti and shake are disabled.

## Notes for the Godot build

- The settings screen should keep the same options: theme, mode, accent, fonts, roundness, ghost strength, edge strength, and the effect toggles.
- Buttons are chunky and press down physically, with a solid shadow underneath that shrinks when pressed.
- Source of truth for the prototype values: the published design prototype. If the app and this file disagree, ask the owner.
