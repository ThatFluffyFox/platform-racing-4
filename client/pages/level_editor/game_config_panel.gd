extends PanelContainer

signal control_event

@onready var grid_container = $MarginContainer/ScrollContainer/GridContainer

const VALUE_WIDTH := 200.0

var line_edit_nodes: Dictionary = {}
var check_box_nodes: Dictionary = {}
var label_overrides: Dictionary = {
	"pr2_physics": "PR2 physics",
	"pr3_physics": "PR3 physics",
}


func _ready():
	hide()
	populate_options()


func populate_options():
	for header in ["Setting", "Default", "Level value"]:
		var header_label = Label.new()
		header_label.text = header
		header_label.modulate = Color(1, 1, 1, 0.6)
		grid_container.add_child(header_label)

	for key in GameConfig.default_values:
		var label = Label.new()
		label.text = label_overrides.get(key, key.replace("_", " ").capitalize())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid_container.add_child(label)

		var default_label = Label.new()
		default_label.text = str(GameConfig.default_values[key])
		grid_container.add_child(default_label)

		if GameConfig.default_values[key] is bool:
			var check_box = CheckBox.new()
			check_box.name = key
			check_box.button_pressed = GameConfig.get_value(key)
			check_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			check_box.toggled.connect(_on_toggled.bind(key))
			grid_container.add_child(check_box)
			check_box_nodes[key] = check_box
			continue

		var line_edit = LineEdit.new()
		line_edit.name = key
		line_edit.custom_minimum_size.x = VALUE_WIDTH
		line_edit.text = str(GameConfig.get_value(key))
		line_edit.connect("text_changed", Callable(self, "_on_text_changed").bind(key))
		grid_container.add_child(line_edit)
		line_edit_nodes[key] = line_edit


func _on_text_changed(new_text: String, key: String):
	var default_value = GameConfig.default_values[key]
	var new_value

	if new_text.is_empty():
		GameConfig.override_values.erase(key)
		return

	if default_value is float:
		new_value = new_text.to_float()
	elif default_value is int:
		new_value = new_text.to_int()
	else:
		new_value = new_text

	if new_value == default_value:
		GameConfig.override_values.erase(key)
	else:
		GameConfig.override_values[key] = new_value


func _on_toggled(pressed: bool, key: String):
	if pressed == GameConfig.default_values[key]:
		GameConfig.override_values.erase(key)
	else:
		GameConfig.override_values[key] = pressed


func toggle():
	if visible:
		hide()
	else:
		show()
		for key in line_edit_nodes:
			line_edit_nodes[key].text = str(GameConfig.get_value(key))
		for key in check_box_nodes:
			check_box_nodes[key].set_pressed_no_signal(GameConfig.get_value(key))
