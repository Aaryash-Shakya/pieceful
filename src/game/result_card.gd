class_name ResultCard
extends RefCounted
## The finished-puzzle summary: the same words on the completion screen and in the shared text.
## Pure formatting, so it is testable without nodes.

const STYLE_NAMES := {
	"regular": "Regular",
	"irregular": "Irregular",
	"wild": "Wild",
}


## 83.4 -> "1:23", 3725 -> "1:02:05". Whole seconds, rounded down, so the card never claims a faster time.
static func format_time(seconds: float) -> String:
	var total := maxi(0, int(floorf(seconds)))
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var secs := total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]


static func style_name(style: String) -> String:
	return STYLE_NAMES.get(style, style.capitalize())


static func pieces_text(count: int) -> String:
	return "%d piece%s" % [count, "" if count == 1 else "s"]


static func ghost_text(ghost: bool) -> String:
	return "Ghost on" if ghost else "Ghost off"


## The lines of the card, one per fact the owner asked for.
static func lines(title: String, puzzle: SaveGame.Puzzle, seconds: float) -> PackedStringArray:
	return PackedStringArray([
		title,
		"%s · %s" % [pieces_text(puzzle.piece_count), style_name(puzzle.style)],
		"%s · %s" % [ghost_text(puzzle.ghost), format_time(seconds)],
	])


## What the share sheet sends.
static func share_text(title: String, puzzle: SaveGame.Puzzle, seconds: float) -> String:
	return "Pieceful\n" + "\n".join(lines(title, puzzle, seconds))
