class_name Share
extends RefCounted
## Hands text to the Android share sheet. Godot has no built-in share, so this uses a share plugin's
## singleton when the build includes one, and otherwise copies the text to the clipboard.

const PLUGIN := "GodotShare"

enum Outcome { SHARED, COPIED }


## True when this build has the share plugin.
static func available() -> bool:
	return Engine.has_singleton(PLUGIN)


static func send(text: String) -> Outcome:
	if available():
		# The plugin's call: title of the chooser, subject, body.
		Engine.get_singleton(PLUGIN).shareText("Pieceful", "Pieceful", text)
		return Outcome.SHARED
	DisplayServer.clipboard_set(text)
	return Outcome.COPIED
