extends PanelContainer
## Level editor panel that imports a Platform Racing 2 level by its ID.

signal level_imported(level: Dictionary)

var id_edit: LineEdit
var import_button: Button
var status_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Import a PR2 level"
	column.add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)

	id_edit = LineEdit.new()
	id_edit.placeholder_text = "Level ID, e.g. 50815"
	id_edit.custom_minimum_size.x = 280
	id_edit.text_submitted.connect(func(_text): _on_import_pressed())
	row.add_child(id_edit)

	import_button = Button.new()
	import_button.text = "Import"
	import_button.pressed.connect(_on_import_pressed)
	row.add_child(import_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(close)
	row.add_child(cancel_button)

	status_label = Label.new()
	status_label.text = "Replaces the level you're editing. PR2 physics is turned on."
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size.x = 480
	column.add_child(status_label)

	hide()


func initialize() -> void:
	show()
	id_edit.grab_focus()


func close() -> void:
	hide()


func _on_import_pressed() -> void:
	if not import_button or import_button.disabled:
		return
	import_button.disabled = true
	status_label.text = "Downloading level " + id_edit.text.strip_edges() + "..."
	var level: Dictionary = await Pr2LevelImporter.fetch(self, id_edit.text)
	import_button.disabled = false
	if level.has("error"):
		status_label.text = level.error
		return
	var title: String = level.get("properties", {}).get("title", "")
	status_label.text = "Imported \"%s\"." % title if title != "" else "Imported."
	level_imported.emit(level)
	close()
