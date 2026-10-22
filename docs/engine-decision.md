# Engine decision

Decision: **Godot 4 with GDScript**, confirmed by the owner on 2026-10-22. The first milestone of version 1 is a spike that must pass the checks below. If it fails, the fallback is libGDX with Kotlin.

The research behind this was done on 2026-10-22 by five web-research passes. Most of the evidence is forum posts, blog posts and search summaries, not full primary reads. **No source gave a benchmark for 400 draggable textured polygons on Android for any option.** The choice rests on risk and track record, and it must be validated on the owner's phone.

## What the game needs from an engine

Up to 400 irregular textured pieces on screen, 60fps dragging with overlap, pinch-zoom and pan, touch hit-testing on irregular shapes, instant-feeling snap sound and vibration, local saves, a fixed on-screen tray, a share action, image downloads, and several menu screens. The owner does not want to build an engine, and APK size is not a hard limit.

## Options compared

| | Godot 4 | libGDX (Kotlin) | Flutter + Flame | Native Android | Unity 2D |
|---|---|---|---|---|---|
| Maintenance and proof | Active (4.6.3, May 2026). Foundation investing in mobile. One shipped open-source jigsaw (F-Droid) | Active (1.14.2, Jun 2026, about 25.5k stars). No jigsaw found | Flame 1.38.2, still pre-2.0. No jigsaw found. Google's I/O crossword team rejected Flame as overkill | No engine. No Compose benchmark for 400 pieces | Most proven commercially for mobile, but the share numbers are marketing-grade |
| 400-piece evidence | None. Vulkan renderers do not batch 2D draws (inference) | None. One shared texture should batch well (inference) | None | None | None |
| Android audio | Older OpenSL ES driver. A request for an Oboe driver has been open since 2021. A 4.6 forum thread reports delay | Default is "not great" per its own wiki. Oboe and miniaudio bindings exist | `flutter_soloud` (miniaudio). No latency numbers | Oboe or AAudio directly, the best path, needs native code | Forum complaints. Fixes are paid or third-party plugins |
| Haptics and share | Duration plus amplitude only. Share is a community plugin tested on 4.3 | Basic vibrate. Richer effects and share by calling Android directly | `vibration` supports amplitude. `share_plus` is solid | Predefined click effects, standard share sheet | Needs plugins |
| Menus and UI | Built in | Scene2D, dated | Strongest | Compose is excellent | Built in |
| APK size | About 17 MiB (the shipped jigsaw) | Not researched | 22 MB or more (anecdote) | Smallest | About 30 to 60 MB (forum posts) |
| Main drawback | Audio latency, unproven rendering | No editor, UI polish by hand | Polygon hitboxes must be convex but jigsaw tabs are concave | Most code to write | Linux editor officially Ubuntu only. The owner runs CachyOS |

## Why Godot

- It provides the hardest parts of this game out of the box: a camera, tweens, textured polygons, hit-testing helpers, touch input and UI nodes.
- It has no engine-share or licensing risk, and it is actively maintained for mobile.
- The cut generator is plain logic, so the engine choice stays reversible.

## Risks found, and the checks they create

1. **Audio latency.** Godot's Android audio driver is OpenSL ES. Reported fixes are an Oboe-based plugin or a custom engine build. No millisecond figures exist.
2. **Rendering 400 pieces.** The only data was a Godot 3 thread that held 60fps below about 25 polygons. It is old and weak.
3. **Polygon edges.** `Polygon2D` has no antialias setting. Smooth edges need 2D MSAA, which is available in the Mobile and Forward+ renderers but not in Compatibility.
4. **Pinch gestures.** `InputEventMagnifyGesture` on Android needs a project setting. A fallback is to track raw touch and drag events and compute the pinch.
5. **Haptics.** Godot offers only duration and strength. Richer effects need an Android plugin.
6. **Share sheet.** A community plugin exists, tested on Godot 4.3. Check it on the version in use, or write a small plugin from the official template.
7. **Device variety.** The Godot Foundation reports Android GPU driver diversity (12,000 or more devices) as the main stability issue. Two shipped games launched with crash rates near 4%, which fixes in 4.5.2 and 4.6 brought under 1%. Use a current stable version.

## Spike pass or fail checks (proposed, awaiting owner confirmation)

Run on the owner's real phone, at 400 pieces, the maximum.

1. 60fps while dragging pieces and while pinch-zooming and panning.
2. The snap sound feels instant to the owner. If not, try an Oboe-based plugin before judging the engine.
3. Piece edges look clean, using MSAA where needed.
4. Pinch and pan work reliably, through the project setting or raw touch events.

If check 1 or 2 cannot be fixed, switch to libGDX with an Oboe or miniaudio add-on. Pieces may need pre-baked sprites instead of `Polygon2D` if rendering is too slow. See "Architecture rules" in `AGENTS.md`.

## What was not verified

Godot's Android audio fix status, any Polygon2D batching behaviour, Godot GUT and gdUnit4 test-framework status on current Godot, libGDX gesture and polygon classes in this research pass, Flame camera and effects APIs, and what the large commercial jigsaw apps use.

## Sources

- Godot audio latency thread: https://forum.godotengine.org/t/audio-latency-on-android-devices/134704
- Godot mobile update, April 2026: https://godotengine.org/article/godot-mobile-update-apr-2026/
- Godot 2D antialiasing: https://docs.godotengine.org/en/4.5/tutorials/2d/2d_antialiasing.html
- Godot 2D performance note: https://docs.godotengine.org/de/4.3/_sources/tutorials/performance/gpu_optimization.rst.txt
- Godot Android plugins: https://docs.godotengine.org/en/stable/tutorials/platform/android/android_plugin.html
- Godot magnify gesture: https://docs.godotengine.org/en/4.2/classes/class_inputeventmagnifygesture.html
- Godot jigsaw on F-Droid: https://f-droid.org/packages/io.gitlab.derjosef.jigsaw/
- libGDX audio wiki: https://libgdx.com/wiki/audio/audio
- libGDX releases: https://api.github.com/repos/libgdx/libgdx/releases
- Flame collision docs: https://docs.flame-engine.org/latest/flame/collision_detection.html
- Google I/O crossword and Flame: https://verygood.ventures/blog/how-we-built-it-creating-the-i-o-crossword-puzzle-powered-by-ai.md
- Android low-latency audio (Oboe): https://developer.android.com/games/sdk/oboe/low-latency-audio
- Unity runtime fee cancelled: https://unity.com/blog/unity-is-canceling-the-runtime-fee
- Unity Linux requirements: https://docs.unity.com/en-us/engine/6000.6/manual/get-started/install-and-upgrade/getting-started-installing-unity/system-requirements
- Mobile engine share (marketing-grade): https://appradar.com/blog/mobile-game-engines-development-platforms
