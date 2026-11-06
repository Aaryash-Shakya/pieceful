class_name FloatingNav
extends PanelContainer
## The tab bar that floats over the main screens. Not mounted anywhere yet.

signal tab_pressed(id: StringName)

const TABS := [[&"home", "Home"], [&"pictures", "Pictures"], [&"daily", "Daily"], [&"settings", "Settings"]]
const ICONS := {
	&"home": "res://assets/icons/home.svg",
	&"pictures": "res://assets/icons/image.svg",
	&"daily": "res://assets/icons/cal.svg",
	&"settings": "res://assets/icons/set.svg",
}

var buttons := {}
var active := &""


func _init() -> void:
	theme_type_variation = UiTheme.NAV
	var row := HBoxContainer.new()
	add_child(row)
	var group := ButtonGroup.new()
	for tab in TABS:
		var id: StringName = tab[0]
		var button := Button.new()
		button.theme_type_variation = UiTheme.OPTION
		button.toggle_mode = true
		button.button_group = group
		button.text = tab[1]
		button.icon = load(ICONS[id])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_pressed.bind(id))
		row.add_child(button)
		buttons[id] = button


# Setting button_pressed under a ButtonGroup never emits `pressed`, so this stays silent.
func set_active(id: StringName) -> void:
	if not buttons.has(id):
		return
	active = id
	(buttons[id] as Button).button_pressed = true


func _on_pressed(id: StringName) -> void:
	active = id
	tab_pressed.emit(id)
