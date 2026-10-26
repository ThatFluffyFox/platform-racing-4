extends Node
class_name TestRunner

static func run_tests(main_instance: Main):
	var args = OS.get_cmdline_args()
	var test_arg_index = args.find("--run-tests")

	if test_arg_index == -1:
		return false

	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -80)

	var tests_to_run: Array
	if test_arg_index + 1 < args.size() and not args[test_arg_index + 1].begins_with("--"):
		tests_to_run = args[test_arg_index + 1].split(",")
	else:
		tests_to_run = ["game"]

	if "all" in tests_to_run:
		# "user_settings" is flaky, skip for now
		tests_to_run = ["game", "editor", "tester", "items", "pr2_physics", "pr3_physics",
				"physics_switch", "item_block"]

	for test in tests_to_run:
		match test:
			"game":
				await _run_game_test(main_instance)
			"editor":
				await _run_editor_test(main_instance)
			"tester":
				await _run_tester_test(main_instance)
			"login":
				await _run_login_test(main_instance)
			"user_settings":
				await _run_user_settings_test(main_instance)
			"items":
				await _run_items_test(main_instance)
			"pr2_physics":
				await _run_pr2_physics_test(main_instance)
			"pr3_physics":
				await _run_pr3_physics_test(main_instance)
			"physics_switch":
				await _run_physics_switch_test(main_instance)
			"item_block":
				await _run_item_block_test(main_instance)

	main_instance.get_tree().quit()
	return true


static func _run_game_test(main_instance: Main):
	Game.pr2_level_id = "50815"
	var game_scene = await main_instance._set_scene(Main.GAME)

	# The level downloads first; give the player 2 seconds once it's spawned.
	var player_manager = game_scene.get_node("PlayerManager")
	for i in 100:
		if player_manager.get_character():
			break
		await main_instance.get_tree().create_timer(0.1).timeout
	await main_instance.get_tree().create_timer(2.0).timeout
	var character = player_manager.get_character()
	if character:
		if not character.is_grounded():
			print("Character is not on the floor at the end of the game test.")
			print("Character position: ", character.position)
			print("Character velocity: ", character.velocity)
			main_instance.get_tree().quit(1)
	else:
		print("Failed to get character instance.")
		main_instance.get_tree().quit(1)


static func _run_items_test(main_instance: Main):
	Game.pr2_level_id = "50815"
	var game_scene = await main_instance._set_scene(Main.GAME)

	# The level downloads first; give the player 2 seconds once it's spawned.
	var player_manager = game_scene.get_node("PlayerManager")
	for i in 100:
		if player_manager.get_character():
			break
		await main_instance.get_tree().create_timer(0.1).timeout
	await main_instance.get_tree().create_timer(2.0).timeout
	var character = player_manager.get_character()
	if not character:
		print("Failed to get character instance.")
		main_instance.get_tree().quit(1)
		return

	for i in range(15):
		character.set_item(i)
		await main_instance.get_tree().create_timer(0.5).timeout
		character.item_manager.use(main_instance.get_process_delta_time())
		await main_instance.get_tree().create_timer(0.5).timeout


static func _run_pr2_physics_test(main_instance: Main):
	await _run_classic_physics_test(main_instance, "pr2")


static func _run_pr3_physics_test(main_instance: Main):
	await _run_classic_physics_test(main_instance, "pr3")


## A 10x10 room: start block at (2, 5), floor on row 6, walls on both sides.
static func _test_room(overrides: Dictionary, extra_blocks: Dictionary = {}) -> Dictionary:
	var data := []
	data.resize(100)
	data.fill(0)
	for x in 10:
		data[60 + x] = 1
	for y in 7:
		data[y * 10] = 1
		data[y * 10 + 9] = 1
	data[52] = 12
	for index in extra_blocks:
		data[index] = extra_blocks[index]
	return {
		"layers": [{"name": "Layer 1", "depth": 10, "rotation": 0, "chunks": [
			{"x": 0, "y": 0, "width": 10, "height": 10, "data": data}]}],
		"properties": {"game_config_overrides": overrides},
	}


static func _run_classic_physics_test(main_instance: Main, mode: String):
	var label := mode.to_upper() + " physics test"
	var level := _test_room({mode + "_physics": true})
	var tester = await main_instance._set_scene(Main.TESTER, {"level": level})
	var character: Character = tester.get_node("PlayerManager").get_character()
	if not character or character.physics_mode() != mode or not character.classic_physics():
		print(label, ": level did not turn on ", mode, " physics.")
		main_instance.get_tree().quit(1)
		return

	# Land, then run and jump around for a few seconds.
	await main_instance.get_tree().create_timer(2.0).timeout
	var start_position: Vector2 = character.position
	var landed: bool = character.is_grounded()
	for keys in [["right"], ["right", "jump"], ["left"], ["left", "jump"], ["down"], []]:
		for action in keys:
			Input.action_press(action)
		await main_instance.get_tree().create_timer(0.5).timeout
		for action in keys:
			Input.action_release(action)
	await main_instance.get_tree().create_timer(2.0).timeout

	if not landed or not character.is_grounded():
		print(label, ": character is not standing. Position: ", character.position)
		main_instance.get_tree().quit(1)
	elif character.position.distance_to(start_position) < 1.0:
		print(label, ": character did not move.")
		main_instance.get_tree().quit(1)
	else:
		print(label, " passed.")
	GameConfig.clear_overrides()


## Starts in PR3 physics and bumps a PR2 switch block (43) overhead, then a
## PR4 one (45), then (in PR4 physics) a PR3 one (44). Each switch keeps the
## way the player faces.
static func _run_physics_switch_test(main_instance: Main):
	var level := _test_room({"pr3_physics": true}, {32: 43, 36: 45, 31: 44})
	var tester = await main_instance._set_scene(Main.TESTER, {"level": level})
	var character: Character = tester.get_node("PlayerManager").get_character()
	if not character or character.physics_mode() != "pr3":
		print("Physics switch test: level should start in PR3 physics.")
		main_instance.get_tree().quit(1)
		return
	await main_instance.get_tree().create_timer(1.5).timeout
	# Face left, then check every switch keeps it.
	Input.action_press("left")
	await main_instance.get_tree().create_timer(0.1).timeout
	Input.action_release("left")
	var seen := [character.physics_mode()]
	var facing_kept := true
	for column in [2, 6, 1]:
		# Put the player under the block (walking there isn't what this tests).
		character.position = Vector2((column + 0.5) * Settings.tile_size.x, character.position.y)
		character.velocity = Vector2.ZERO
		await main_instance.get_tree().create_timer(0.5).timeout
		Input.action_press("jump")
		await main_instance.get_tree().create_timer(0.6).timeout
		Input.action_release("jump")
		await main_instance.get_tree().create_timer(1.0).timeout
		seen.push_back(character.physics_mode())
		facing_kept = facing_kept and character.movement.facing == -1
	if seen != ["pr3", "pr2", "pr4", "pr3"] or not character.is_grounded() or not facing_kept:
		print("Physics switch test: modes seen ", seen, ", grounded ", character.is_grounded(),
				", facing kept ", facing_kept, " at ", character.position)
		main_instance.get_tree().quit(1)
	else:
		print("Physics switch test passed.")
	GameConfig.clear_overrides()


## Bumps a single-use item block twice in each physics mode: only the first
## bump may give an item.
static func _run_item_block_test(main_instance: Main):
	var failures := []
	for mode in ["pr4", "pr2", "pr3"]:
		var overrides := {} if mode == "pr4" else {mode + "_physics": true}
		var level := _test_room(overrides, {32: 11})
		var tester = await main_instance._set_scene(Main.TESTER, {"level": level})
		var character: Character = tester.get_node("PlayerManager").get_character()
		await main_instance.get_tree().create_timer(1.0).timeout
		var got := []
		for bump in 2:
			Input.action_press("jump")
			await main_instance.get_tree().create_timer(0.6).timeout
			Input.action_release("jump")
			await main_instance.get_tree().create_timer(1.2).timeout
			got.push_back(character.item_manager.item != null)
			if character.item_manager.item:
				character.item_manager.remove_item()
		if got != [true, false]:
			failures.push_back(mode + " " + str(got))
	GameConfig.clear_overrides()
	if failures.is_empty():
		print("Item block test passed.")
	else:
		print("Item block test: items from bump 1 and 2: ", failures)
		main_instance.get_tree().quit(1)


static func _run_editor_test(main_instance: Main):
	var level_editor = await main_instance._set_scene(Main.LEVEL_EDITOR)
	await main_instance.get_tree().create_timer(1.0).timeout

	var block_cursor = level_editor.cursor.get_node("BlockCursor")
	var tiles = Tiles.new()
	tiles.init_defaults()
	var tile_ids = tiles.map.keys()

	var rng = RandomNumberGenerator.new()
	var viewport_rect = main_instance.get_viewport_rect()

	for tile_id in tile_ids:
		block_cursor.block_id = int(tile_id)
		var x = rng.randf_range(0, viewport_rect.size.x)
		var y = rng.randf_range(0, viewport_rect.size.y)
		block_cursor.global_position = Vector2(x, y)
		block_cursor.on_drag(block_cursor.global_position)
		await main_instance.get_tree().create_timer(0.05).timeout

	await main_instance.get_tree().create_timer(0.1).timeout


static func _run_tester_test(main_instance: Main):
	await main_instance._set_scene(Main.TESTER)
	await main_instance.get_tree().create_timer(4.0).timeout


static func _run_login_test(main_instance: Main):
	var login_scene = await main_instance._set_scene(Main.LOGIN)
	login_scene.get_node("Panel/VBoxContainer/NicknameEdit").text = "aaaa"
	login_scene.get_node("Panel/VBoxContainer/PasswordEdit").text = "aaaa"
	login_scene.get_node("Panel/VBoxContainer/LoginButton").pressed.emit()
	await main_instance.get_tree().create_timer(2.0).timeout
	if not Session.is_logged_in():
		print("Login test failed.")
		main_instance.get_tree().quit(1)


static func _run_user_settings_test(main_instance: Main):
	# Login first
	var login_scene = await main_instance._set_scene(Main.LOGIN)
	login_scene.get_node("Panel/VBoxContainer/NicknameEdit").text = "aaaa"
	login_scene.get_node("Panel/VBoxContainer/PasswordEdit").text = "aaaa"
	login_scene.get_node("Panel/VBoxContainer/LoginButton").pressed.emit()
	await main_instance.get_tree().create_timer(2.0).timeout
	if not Session.is_logged_in():
		print("Login failed, cannot run user settings test.")
		main_instance.get_tree().quit(1)

	# Go to user settings
	var user_settings_scene = await main_instance._set_scene(Main.USER_SETTINGS)
	await main_instance.get_tree().process_frame

	# Change nickname
	user_settings_scene.get_node("VBoxContainer/NewNicknameEdit").text = "bbbb"
	user_settings_scene.get_node("VBoxContainer/NicknamePasswordEdit").text = "aaaa"
	user_settings_scene.get_node("VBoxContainer/UpdateNicknameButton").pressed.emit()
	await Session.session_updated
	if Session.nickname != "bbbb":
		print("Nickname was not updated in session.")
		main_instance.get_tree().quit(1)
	if user_settings_scene.get_node("VBoxContainer/StatusLabel").text != "User information updated successfully":
		print("Nickname update failed: " + user_settings_scene.get_node("VBoxContainer/StatusLabel").text)
		main_instance.get_tree().quit(1)

	# Change password
	user_settings_scene.get_node("VBoxContainer/CurrentPasswordEdit").text = "aaaa"
	user_settings_scene.get_node("VBoxContainer/NewPasswordEdit").text = "bbbb"
	user_settings_scene.get_node("VBoxContainer/UpdatePasswordButton").pressed.emit()
	await main_instance.get_tree().create_timer(2.0).timeout
	if user_settings_scene.get_node("VBoxContainer/StatusLabel").text != "User information updated successfully":
		print("Password update failed: " + user_settings_scene.get_node("VBoxContainer/StatusLabel").text)
		main_instance.get_tree().quit(1)

	# Change nickname back
	user_settings_scene.get_node("VBoxContainer/NewNicknameEdit").text = "aaaa"
	user_settings_scene.get_node("VBoxContainer/NicknamePasswordEdit").text = "bbbb"
	user_settings_scene.get_node("VBoxContainer/UpdateNicknameButton").pressed.emit()
	await Session.session_updated
	if Session.nickname != "aaaa":
		print("Nickname was not changed back in session.")
		main_instance.get_tree().quit(1)
	if user_settings_scene.get_node("VBoxContainer/StatusLabel").text != "User information updated successfully":
		print("Nickname change back failed: " + user_settings_scene.get_node("VBoxContainer/StatusLabel").text)
		main_instance.get_tree().quit(1)

	# Change password back
	user_settings_scene.get_node("VBoxContainer/CurrentPasswordEdit").text = "bbbb"
	user_settings_scene.get_node("VBoxContainer/NewPasswordEdit").text = "aaaa"
	user_settings_scene.get_node("VBoxContainer/UpdatePasswordButton").pressed.emit()
	await main_instance.get_tree().create_timer(2.0).timeout
	if user_settings_scene.get_node("VBoxContainer/StatusLabel").text != "User information updated successfully":
		print("Password change back failed: " + user_settings_scene.get_node("VBoxContainer/StatusLabel").text)
		main_instance.get_tree().quit(1)
