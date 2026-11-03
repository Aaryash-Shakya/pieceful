# Feedback: fourth slice of version 1

Read `INTENT.md` and `AGENTS.md` first. They win over this document where they disagree. This document describes only the feedback slice of version 1 in `docs/version-plan.md`: "Sound and vibration on joins (light) and on board locks (stronger)". The previous slice is `docs/superpowers/specs/2026-11-02-snapping-design.md`, which added the board signals this slice listens to.

## Intent

The puzzle snaps exactly, but silently. `INTENT.md` asks for a game that is tactile: "Sound and vibration on joins and on correct placement. A snap should feel good in the hand." This slice gives every snap a sound and a pulse, and does it with as little delay as Godot allows, because the version 1 exit test is "The snap sound and vibration feel instant". If they do not feel instant on the owner's phone, that is a spike failure (`docs/engine-decision.md`, risk 1), and the answer is an Oboe-based audio plugin, not more tuning here.

The sounds are short files, as `docs/technical-notes.md` asks, but they are made by a script in the project, so they are the owner's own work, reproducible, and carry the character of the prototype's code-generated sounds.

## What the slice delivers

1. **Four sound files** in `assets/sounds/`: `pick.wav` (a light tick on pick-up), `join.wav` (a short click on a join), `lock.wav` (a lower, firmer thump on a lock) and `complete.wav` (a rising chord on completion). Mono, 16-bit PCM, 44 100 Hz, no silence at the start, imported uncompressed. Lengths: pick 50 ms, join 70 ms, lock 120 ms, complete 930 ms.
2. **A generator.** `tools/sound_synth.gd` renders each sound into an `AudioStreamWAV` from a fixed recipe, and `tools/make_sounds.gd` writes the four files with `AudioStreamWAV.save_to_wav`. It runs headless (`godot --headless --script tools/make_sounds.gd`), uses the project's `SeededRng` for its one noise burst and no engine random, and gives the same bytes on every run. The generated files and their `.import` files are committed.
3. **A licence note**, `assets/sounds/LICENSE.md`: the sounds are the owner's own work, made by `tools/make_sounds.gd`, licensed CC BY 4.0 (`docs/open-decisions.md` #12 default).
4. **A pick-up signal on the board**: `cluster_lifted(cluster_root: int, piece_count: int)`, emitted once when a finger picks up a loose cluster. Pressing empty table, a locked piece, or a second finger during a hold emits nothing.
5. **A feedback node.** `Feedback` (`src/game/feedback.gd`), a `Node` child of the board scene, listens to `cluster_lifted`, `pieces_joined`, `cluster_locked` and `puzzle_completed` and plays:

   | Event | Sound | Vibration (duration, amplitude) |
   |---|---|---|
   | Pick-up | pick | none |
   | Join only | join | 12 ms, 0.5 |
   | Lock (with or without a join in the same drop) | lock | 25 ms, 1.0 |
   | Completion (after the last lock) | complete, on top of the lock | 60 ms, 1.0 |

6. **Low latency within Godot.** Streams are preloaded. Each sound has one `AudioStreamPlayer` made once in `_ready`, with `max_polyphony` 4, so overlapping snaps do not cut each other off and nothing is created or loaded per play.
7. **On and off switches**: `sound_enabled` and `vibration_enabled` on the node, both `true`, with no UI. The version 2 settings screen sets them.
8. **A test seam.** The node plays through two `Callable` fields, `play_sound(sound: StringName)` and `vibrate(duration_ms: int, amplitude: float)`, which default to the real players and `Input.vibrate_handheld`. Tests replace them with recorders.
9. **The Android vibrate permission** in the export preset (`permissions/vibrate=true`). It is a normal permission, so no prompt is shown.
10. **Docs.** The audio driver finding below goes into `docs/engine-decision.md`, and the sound and haptic values into `docs/technical-notes.md`.

## The sounds

Ported from the prototype's `sfx` table in `docs/prototype/pieceful-prototype.html`, with the same pitches, waveforms and relative volumes. A tone sweeps its frequency exponentially from its start to its end pitch over its length, rises linearly to its volume over 1 ms and then decays exponentially to 0.0001 of its volume at its end. A click is white noise shaped by `(1 - t / length)^3`, starting at full volume. Components are summed, multiplied by a master gain of 1.5 (so the loudest moment, in the lock, stays below full scale), clamped and quantised to 16 bits.

| File | Components (start, length, volume) | Length |
|---|---|---|
| pick | triangle 320 to 260 Hz (0, 50 ms, 0.05) | 50 ms |
| join | triangle 640 to 470 Hz (0, 70 ms, 0.14); click (0, 30 ms, 0.08) | 70 ms |
| lock | sine 230 to 120 Hz (0, 120 ms, 0.3); triangle 900 to 640 Hz (10 ms, 100 ms, 0.12); click (0, 50 ms, 0.18) | 120 ms |
| complete | sines at 523, 659, 784 and 1047 Hz, steady, each (110 ms times its index, 600 ms, 0.14) | 930 ms |

## The audio driver finding

On 2026-11-03 the Godot sources at `4.5-stable` and at `master` were read (`platform/android/audio_driver_opensl.cpp`; 4.7.2 sits between them, and Android has no other audio driver in either). The OpenSL ES driver hard-codes a 44 100 Hz mix rate and two buffers of 1024 frames, about 46 ms of buffering inside Godot before Android's own output path, and it reads no project setting. `audio/driver/output_latency` and `audio/driver/mix_rate` therefore have no effect on Android. This slice does not set them, records the finding, and matches the files to the fixed 44 100 Hz rate so Godot never resamples them. Whether 46 ms plus the device's path feels instant is the owner's phone check; if it does not, the next step is the Oboe-based plugin (`docs/engine-decision.md`).

## Goals

- Every pick-up, join, lock and completion produces the feedback in the table, in the same frame as the board's signal, with no frame of delay added by the game.
- A drop that joins and locks plays only the lock feedback, the stronger one.
- Two snaps in quick succession both play in full.
- Turning sound off silences every sound and keeps vibration, and the other way round.
- The generator gives identical bytes on every run, and the committed files match it.
- Dragging stays at 60 frames per second: the node does nothing per frame and nothing during a drag.

## Non-goals for this slice

- The settings screen and saving the two switches (version 2).
- The snap ring, confetti, the board shake and any other effect.
- Music and any sound beyond the four.
- The Oboe plugin or a custom Godot build. It is the recorded fallback.
- The cleanup button, saving and resuming.
- The prototype's slot sound (slots are version 2).

## Anti-goals

- Silence or a fade-in at the start of a sound file. The first millisecond must already be audible.
- Compressed (QOA or ADPCM) imports, which Godot uses by default for WAV files.
- Loading a stream, creating a node or connecting a signal while playing.
- Two different feedbacks for one drop.
- Any sound file that is not the owner's own, CC0 or public domain.

## Constraints

- Godot 4.7.2, GDScript, Mobile renderer. Android only. Package name `io.github.aaryash_shakya.pieceful`, do not change it.
- No new dependencies, plugins or network calls.
- The generator uses `SeededRng` (`src/cut/seeded_rng.gd`) for randomness, never the engine's random functions.
- Tests are plain headless scripts extending `BaseTest`, run with `godot --headless --script tests/<name>.gd`.
- Match the style of the surrounding code. Keep comments sparse and explain why.

## Decisions the owner made

- Sound and vibration on joins (light) and on board locks (stronger) are in version 1; settings for them and polish of audio and haptics are in version 2 (`docs/version-plan.md`).
- From the prototype (`docs/technical-notes.md`): a light tick on pick-up, a short click on a join, a lower, firmer thump on a lock, a rising chord on completion; a light pulse on a join and a firm pulse on a lock. The real app uses short sound files.
- The snap sound must feel instant; if it does not, try an Oboe-based plugin before judging the engine (`docs/engine-decision.md`).
- Vibration is an Android permission the app needs (`docs/technical-notes.md`).

## Calls made by Claude, which the owner has not confirmed

The orchestrator was delegated these decisions by the owner. Each one below is Claude's, or the orchestrator's where marked.

- **Generated sounds, CC BY 4.0** (orchestrator). The files are made by a project script and licensed under the `docs/open-decisions.md` #12 default.
- **No latency setting.** The brief asked for the Android output latency setting to be set as low as is sensible. Godot's Android driver ignores it (see the finding above), so setting it would record a value that does nothing. The slice records the finding instead and tests the one thing that does matter on Android, that the files are at the driver's fixed 44 100 Hz.
- **44 100 Hz, not 48 000 Hz.** Godot mixes at 44 100 Hz on Android, so a 48 000 Hz file would be resampled on every play.
- **A 1 ms linear attack** instead of the prototype's 6 ms exponential ramp, which starts at 0.0001 and stays nearly silent for its first few milliseconds. 1 ms is long enough to avoid a click at the start of a tone.
- **Lock shortened from 160 ms to 120 ms**, with its overtone starting at 10 ms instead of 20 ms, to stay well under 150 ms. **The chord's notes ring 600 ms** instead of 400 ms, so the chord lasts about 1 s as asked.
- **Master gain 1.5** keeps the prototype's balance between the sounds and keeps the lock's peak, its components' volumes summed, at most 0.9 of full scale. The pick tick is then quiet (about -22 dBFS), as the prototype had it.
- **Vibration values.** Join 12 ms at 0.5, lock 25 ms at 1.0, completion 60 ms at 1.0. The prototype used 9 ms and 22 ms with no amplitude; 9 ms is below what many phone motors can render. None on pick-up, as asked.
- **Completion plays both the lock thump and the chord**, as the prototype did, and both vibrations. On Android a second vibration replaces the first, so the player feels the 60 ms pulse.
- **Join-and-lock is decided by the state.** When `pieces_joined` arrives, the node asks `board.state.is_locked(cluster_root)`; if the cluster already locked, it plays nothing, because `cluster_locked` follows in the same call. This needs no deferred call, so it adds no delay, and the board's signals stay as the snapping slice defined them.
- **The engine's polyphony instead of a hand-made pool.** `AudioStreamPlayer.max_polyphony` is Godot's built-in way to let a player overlap its own sound (`AGENTS.md`: prefer the built-in feature). Four voices per sound covers four snaps within one sound's length. Each `play()` still makes the engine's small playback object; no game code allocates.
- **Pick-up signal timing.** `cluster_lifted` is emitted in `_begin_single` after the cluster is held and raised, with the held node count, so the tick is in the same frame as the lift shadow.
- **Feedback finds the board through an exported `board: Board` field**, set to `..` in `board.tscn`, and connects in its `_ready`. The node works with no board set, which is what the format tests use.
- **The generator lives in `tools/`** with no `class_name`, so it adds no global class. Tests load it by path. `tools/` is exported into the APK like `tests/` is today; excluding both is a separate small change.
- **The committed files must match the generator** within one 16-bit step per sample, which allows for a different maths library on another machine.

## Left to the builder

- Private helper and field names, and whether the callables are set in `_init` or as member defaults, inside the interfaces the plan fixes.
- How the synth loops over components, as long as each sample follows the formulas in "The sounds".

## What happens if the snap does not feel instant

The owner checks on the Nothing Phone (4a) whether the join and lock feel instant. If the vibration feels instant and the sound lags, the cause is the audio path, and the fallback is an Oboe-based Android plugin (`docs/engine-decision.md`, risk 1), which needs the owner's agreement because it adds a dependency. If both lag, the cause is input or frame timing, not audio, and is measured with the frame-rate counter first. If the pulses are too weak or too strong, only the six vibration constants change. Record the results in `docs/engine-decision.md`.
