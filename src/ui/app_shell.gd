class_name AppShell
extends Control
## The app's one persistent root. It holds a stack of screens and the look every screen inherits.

signal look_applied

var settings_path := Settings.DEFAULT_PATH
## The save the default Home reads.
var save_path := SaveFile.DEFAULT_PATH
## Returns the root screen. Left empty, the Home screen is the root.
var make_home := Callable()

var _stack: Array[Node] = []


func _ready() -> void:
	add_to_group("app_shell")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The shell only holds screens. Left on STOP it swallows touches the board needs from _unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Settings.use(Settings.load_from(settings_path))
	apply_look()
	if make_home.is_valid():
		push(make_home.call())
	else:
		push(HomeScreen.make_host(save_path, CollectionLibrary.load_bundled(), get_tree().quit))


func push(screen: Node) -> void:
	if _stack.has(screen):
		return
	if top() != null:
		remove_child(top())
	_stack.append(screen)
	_show(screen)


func pop() -> bool:
	if _stack.size() < 2:
		return false
	# Out of the tree first, like replace(), so only the top screen is ever a child.
	var old: Node = _stack.pop_back()
	remove_child(old)
	old.queue_free()
	add_child(_stack.back())
	return true


func replace(screen: Node) -> void:
	var old: Node = _stack.pop_back() if not _stack.is_empty() else null
	if old != null:
		# Out of the tree now so the new screen is the only child, freed at the frame's end.
		remove_child(old)
		old.queue_free()
	_stack.append(screen)
	_show(screen)


func top() -> Node:
	return null if _stack.is_empty() else _stack.back()


func depth() -> int:
	return _stack.size()


func safe_insets() -> Vector4:
	return SafeArea.current(get_tree())


func apply_look() -> void:
	RenderingServer.set_default_clear_color(Palette.page_background())
	theme = UiTheme.build()
	look_applied.emit()


static func find(tree: SceneTree) -> AppShell:
	return tree.get_first_node_in_group("app_shell") as AppShell


## Screens call this instead of changing the scene, so the shell stays the root when there is one.
static func present(tree: SceneTree, screen: Node) -> void:
	var shell := find(tree)
	if shell != null:
		# Deferred like change_scene_to_node: a back notification arrives while the tree is busy.
		shell.replace.call_deferred(screen)
	else:
		tree.change_scene_to_node(screen)


func _show(screen: Node) -> void:
	add_child(screen)
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Screens pushed over are out of the tree, so freeing the shell would not reach them.
		for screen in _stack:
			if is_instance_valid(screen) and screen.get_parent() != self:
				screen.free()
