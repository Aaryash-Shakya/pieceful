# Intent

This file records what the project owner wants and why. It is the reference for judgment calls. When a detail is not specified anywhere, decide in the way that best serves what is written here. Where this file and a suggestion from an agent disagree, this file wins.

## What this is

A jigsaw puzzle game for Android. The player picks a picture from a collection, chooses how many pieces to cut it into and what style of pieces, and solves it on a phone.

It is a personal project. It is distributed as an APK on GitHub. It is not meant to make money.

## Why it exists

Most mobile jigsaw apps are full of ads and feel sluggish. The owner wants one that is:

- **Free of ads, tracking and monetization.** This is the biggest selling point, and it does not change.
- **Smooth and fast.** Dragging, zooming and snapping should never stutter. Optimizing for responsiveness is a priority over adding features.
- **Tactile.** Sound and vibration on joins and on correct placement. A snap should feel good in the hand.
- **Adjustable in difficulty.** The same app should work as a relaxing puzzle or a brutally hard one, depending on the settings.

## How the player experiences it

- Piece count is chosen with a slider from about 12 to 400. The slider moves between valid rows-by-columns splits that fit the image's aspect ratio, so the counts are values such as 15, 18 or 35, not every integer.
- Cut style is one of three: Regular (classic jigsaw tabs on a grid), Irregular (a grid with uneven sizes and wobbly cuts, still four-sided), and Wild (arbitrary shapes such as triangles and trapezoids, with interlocking edges). The setup screen shows the cut lines over the actual image as a live preview.
- The third difficulty control is a faint ghost image over the board, switched on or off. It is on by default, at 20% opacity.
- The board and the loose pieces share one world that can be pinch-zoomed and panned. Pieces never rotate.
- Loose pieces sit around the board. A cleanup button arranges them neatly, packed row by row.
- Two pieces that fit join permanently into a cluster that moves as one, with a light sound and a light vibration. A piece or cluster dropped on its correct board position locks in place, with a stronger sound and vibration.
- Four slots at the bottom of the screen let the player sort pieces by color or type, for example sky, branches or roofs. A slot holds a messy stack, and the player can only take out the whole stack at a time. Touching a slot fans the stack out under the finger. Releasing near the slot returns it. Dragging it away and releasing spreads the pieces in an even grid where the finger lifted. Each slot shows a count badge.
- A game can be left half-finished and resumed. The save includes loose piece positions, clusters, slot contents and elapsed time.
- Finishing a puzzle shows a completion screen with the puzzle name, piece count, cut style, ghost overlay setting and time. A result card with the same information can be shared through the Android share sheet so friends can compare.
- A daily puzzle uses a fixed seed so everyone gets the identical cut. Its difficulty ramps through the week, so the share card ("Wednesday, 150 pieces, Irregular, 12:34") is comparable. The day is counted in UTC, the ghost image is always on, and the picture comes from the bundled images only. The planned ramp (the style and counts are Claude's suggestion that the owner approved in principle) is Monday Regular 54, Tuesday Regular 96, Wednesday Irregular 150, Thursday Wild 200, Friday Wild 250, Saturday Wild 300 and Sunday Regular 400.

## Content

- Images are public domain, CC0, the owner's own photos, or AI-generated. Nothing else is bundled.
- Images are grouped into collections such as nature, art, architecture, animals and cats, about 10 to 15 images each.
- The app ships with about four collections so it is fully usable offline. More collections are downloaded from a store screen, hosted on Cloudflare R2. Once downloaded they stay available offline. Resetting game progress must never delete downloaded collections.
- The daily puzzle is chosen from bundled images only, so it never needs a network.

## Goals

- A smooth, tactile, ad-free jigsaw experience on Android.
- One generator that produces all cut styles deterministically from a seed.
- A codebase simple enough that one person can keep it working.

## Non-goals

- Monetization of any kind.
- Online leaderboards, accounts or any server beyond static image hosting.
- iOS release. It is acceptable if the engine could export there, but it is not tested or shipped.
- Piece rotation.
- Hexagonal or other cut styles beyond the three listed.

## Anti-goals

These would make the project a failure even if everything technically works:

- Any ad, tracker or paywall.
- Stutter or visible lag while dragging pieces.
- A home-built engine with many fragile custom subsystems. The owner prefers a reasonable engine over writing everything from scratch.
- A large, bloated APK caused by bundling every image. Size matters for images, which is why only a few collections ship in the APK.

## Decisions already made

- Engine: Godot 4. Version 1 doubles as the performance test.
- Language: GDScript is assumed. The owner has not confirmed this.
- Android package name: `io.github.aaryash_shakya.pieceful`. It cannot change once an APK is shipped.
- Cut geometry is generated, not stored. Saves hold the image, style, count and seed.
- Wild pieces have knobbed edges so they interlock, like the owner's reference screenshots. This is an assumption the owner has not rejected.
- Slots are planned for version 2, not version 1. This is an assumption the owner has not rejected.

## Open items

- Confirm GDScript as the language.
- Confirm slots in version 2.
- Pick the project name.
