# Pieceful

A free, ad-free jigsaw puzzle game for Android. No ads, no tracking, no accounts. It is smooth, tactile and works offline.

**Status:** version 1 is built and waiting for testing on a real phone. It is a Godot 4 project written in GDScript.

## What version 1 does

- Pick a picture from the bundled collection, choose Regular or Irregular pieces, and set 12 to 400 pieces on a slider that stops only at valid counts, with a live preview of the cut.
- Drag pieces with one finger, pinch-zoom and pan, and join pieces that fit into clusters that lock in place. Sound and vibration on joins and locks.
- A Tidy button packs loose pieces around the board.
- Leave and come back: the game saves after every lock and when the app pauses, and resumes exactly where you left it.

## What is planned

- Four sorting slots, a completion screen, a timer and settings (version 2).
- Wild pieces, a daily puzzle that is the same for everyone, and downloadable picture collections (version 3).

## Build and install

Follow `docs/dev-setup.md` to install the tools, then run `tools/build_apk.sh` to build the debug APK and install it on a connected phone. Tests run headless: `godot --headless --script tests/<name>.gd`.

## Where to read more

- `INTENT.md`: what the project is for and why.
- `docs/v1-status.md`: what is built, the decisions made while building it, and what to check on the phone.
- `docs/version-plan.md`: the planned versions.
- `docs/open-decisions.md`: what is not decided yet.
- `AGENTS.md`: notes for AI coding agents working in this repository.

## Licence and credits

The code is released under the MIT licence. See `LICENSE`. You may use, copy, modify and sell it, as long as you keep the copyright notice and licence text with your copy. A mention of Pieceful and a link back to this repository is appreciated.

Pictures, fonts and sounds are not covered by the code licence. Each keeps its own licence, recorded in the manifest next to it. The fonts Baloo 2 and Quicksand are used under the SIL Open Font License.
