class_name GoalWindow
extends PanelContainer
## The goal window of the client (MissionPopup and PopupGoalList): one goal
## with its picture, character, description, reward and progress, or the list
## of the active goals. The port shows it with the controls of Godot; the art
## of the client's window comes with step 5 of the roadmap.

## The player pressed "DO IT" for the goal; see GoalBook.hint().
signal do_it(goal: GameConfig.GoalDef)
signal closed

const WIDTH := 460
const PICTURE_HEIGHT := 120

var _goals: GoalBook
var _config: GameConfig
var _images_dir: String
var _content := VBoxContainer.new()


## images_dir: the folder with the pictures of the goals (ui/images of the import).
func _init(goals: GoalBook, config: GameConfig, images_dir: String) -> void:
	_goals = goals
	_config = config
	_images_dir = images_dir
	custom_minimum_size.x = WIDTH
	set_anchors_preset(Control.PRESET_CENTER)
	add_child(_content)


func _ready() -> void:
	position = (get_viewport_rect().size - Vector2(WIDTH, 0)) / 2 - Vector2(0, 150)


func show_goal(goal: GameConfig.GoalDef) -> void:
	_clear()
	var pictures := HBoxContainer.new()
	for name in [goal.image, goal.character]:
		var texture := _load_picture(name)
		if texture != null:
			var picture := TextureRect.new()
			picture.texture = texture
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			picture.custom_minimum_size = Vector2(texture.get_width() * PICTURE_HEIGHT / float(texture.get_height()), PICTURE_HEIGHT)
			pictures.add_child(picture)
	if pictures.get_child_count() > 0:
		_content.add_child(pictures)
	_label(_goals.text(goal.title), true)
	_label(_goals.text(goal.description))
	_label("Reward: %d gold. Progress: %s" % [goal.reward, _goals.progress_text(goal)])
	var buttons := HBoxContainer.new()
	_button(buttons, _config.text("GOALS_GO").strip_edges(), func() -> void: do_it.emit(goal))
	_button(buttons, _config.text("OPEN_GOAL_LIST").strip_edges(), show_list)
	_button(buttons, "Close", _close)
	_content.add_child(buttons)


func show_list() -> void:
	_clear()
	_label(_config.text("OPEN_GOAL_LIST").strip_edges(), true)
	for goal in _goals.active_goals():
		var row := HBoxContainer.new()
		_button(row, "%s  %s  (%d gold)" % [_goals.text(goal.title), _goals.progress_text(goal), goal.reward], show_goal.bind(goal))
		_content.add_child(row)
	var buttons := HBoxContainer.new()
	_button(buttons, "Close", _close)
	_content.add_child(buttons)


func _clear() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()


func _label(text: String, title := false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = WIDTH - 20
	if title:
		label.add_theme_font_size_override("font_size", 20)
	_content.add_child(label)


func _button(parent: Container, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _close() -> void:
	closed.emit()
	queue_free()


## The picture, or null when the import does not have it.
func _load_picture(name: String) -> Texture2D:
	var path := _images_dir.path_join(name)
	if name == "none" or not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	return ImageTexture.create_from_image(image) if image != null else null
