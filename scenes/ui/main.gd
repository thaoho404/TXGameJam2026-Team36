extends Control

const BOSS_2_TEXTURE: Texture2D = preload("res://art-assets/sprites/reveille_normal_sprite.png")

@onready var title_screen: Control = $MainMenu/Panel
@onready var start_screen: Control = $MainMenu/StartChoiceMenu
@onready var upgrade_screen: Control = $MainMenu/UpgradeMenu
@onready var gacha_screen: Control = $MainMenu/GachaMenu
@onready var credit_screen: Control = $MainMenu/CreditMenu
@onready var game_screen: Control = $MainMenu/GamePlay
@onready var turn_manager: TurnManager = $TurnManager
@onready var pinball_table: PinballController = $MainMenu/GamePlay/HBoxContainer/PinballBoard/SubViewport/PinballTable
@onready var combat_ui: Control = $MainMenu/GamePlay/HBoxContainer/CombatUI
@onready var enemy_sprite: TextureRect = combat_ui.get_node("EnemySprite")
@onready var boss_1_texture: Texture2D = enemy_sprite.texture
@onready var enemy_health_bar: TextureProgressBar = combat_ui.get_node("EnemyHealthBar")
@onready var player_health_bar: TextureProgressBar = combat_ui.get_node("PlayerHealthBar")
@onready var enemy_hp_label: Label = combat_ui.get_node("EnemyHPLabel")
@onready var player_hp_label: Label = combat_ui.get_node("PlayerHPLabel")
@onready var score_label: Label = combat_ui.get_node("ScorePanel/ScoreLabel")
@onready var battle_status: Label = combat_ui.get_node("DialogueBox/BattleStatus")
@onready var retry_button: Button = $MainMenu/GamePlay/HBoxContainer/CombatUI/RetryButton
@onready var roll_label: Label = $MainMenu/GachaMenu/Panel/GachaContent/RollLabel
@onready var reroll_button: Button = $MainMenu/GachaMenu/Panel/GachaContent/RerollButton
@onready var continue_button: Button = $MainMenu/StartChoiceMenu/StartChoiceContent/ContinueButton

var profile := RunProfile.new()
var currency_label: Label
var upgrade_buttons: Dictionary = {}
var run_label: Label
var _run_revision: int = 0


func _ready() -> void:
	profile.load_profile()
	pinball_table.ball_launched.connect(turn_manager.on_ball_launched)
	pinball_table.ball_rearmed.connect(_update_battle_ui)
	pinball_table.plunger.ball_launched.connect(_update_battle_ui)
	pinball_table.bumper_hit.connect(turn_manager.register_board_hit)
	pinball_table.ball_drained.connect(turn_manager.on_ball_drained)
	turn_manager.turn_ready.connect(pinball_table.prepare_next_ball)
	turn_manager.state_changed.connect(_on_battle_state_changed)
	turn_manager.battle_updated.connect(_update_battle_ui)
	turn_manager.damage_dealt.connect(_on_damage_dealt)
	turn_manager.ball_speed_changed.connect(pinball_table.apply_speed_multiplier)
	turn_manager.battle_finished.connect(_on_battle_finished)
	_build_menus()
	show_screen(title_screen)
	_update_battle_ui()


func _menu(parent: Control, heading: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -230
	box.offset_top = -170
	box.offset_right = 230
	box.offset_bottom = 170
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	var title := Label.new()
	title.text = heading
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	return box


func _build_menus() -> void:
	#$MainMenu/UpgradeMenu/Panel/TempText.hide()
	var upgrade_box := _menu($MainMenu/UpgradeMenu/Panel, "Permanent upgrades")
	currency_label = Label.new()
	currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_box.add_child(currency_label)
	var names := {"balls": "Extra starting ball", "rerolls": "Extra reroll", "damage": "Flat damage", "hp": "Maximum HP", "money": "Currency multiplier"}
	for key in RunProfile.UPGRADE_KEYS:
		var button := Button.new()
		button.pressed.connect(_on_upgrade_pressed.bind(key))
		upgrade_box.add_child(button)
		upgrade_buttons[key] = {"button": button, "label": names[key]}

	run_label = Label.new()
	run_label.name = "RunStatus"
	run_label.position = Vector2(30, 205)
	run_label.size = Vector2(460, 65)
	run_label.add_theme_font_size_override("font_size", 18)
	run_label.add_theme_color_override("font_outline_color", Color.BLACK)
	run_label.add_theme_constant_override("outline_size", 4)
	combat_ui.add_child(run_label)


func show_screen(screen: Control) -> void:
	if screen != game_screen:
		turn_manager.stop_battle()
		pinball_table.stop_board()
	for page in [title_screen, upgrade_screen, gacha_screen, credit_screen, game_screen, start_screen]:
		page.hide()
	screen.show()
	get_viewport().gui_release_focus()


func _on_play_button_pressed() -> void:
	continue_button.disabled = not FileAccess.file_exists(profile.save_path)
	show_screen(start_screen)


func _on_new_game_pressed() -> void:
	profile.new_game()
	_open_gacha()


func _on_continue_pressed() -> void:
	# Returning from the roll screen keeps its choice and spent rerolls.
	if not profile.run_active:
		profile.load_profile()
		profile.begin_run()
	_open_gacha()


func _open_gacha() -> void:
	_run_revision += 1
	_refresh_gacha()
	show_screen(gacha_screen)


func _refresh_gacha() -> void:
	var chosen := profile.current_ball
	if chosen == null:
		roll_label.text = "No ball types are available."
		$MainMenu/GachaMenu/Panel/ReadyButton.disabled = true
		return
	roll_label.text = "%s  •  %s\n%s" % [chosen.display_name, BallType.Rarity.keys()[chosen.rarity].capitalize(), chosen.description]
	reroll_button.text = "Reroll (%d left)" % profile.rerolls_left
	reroll_button.disabled = profile.rerolls_left <= 0
	$MainMenu/GachaMenu/Panel/ReadyButton.disabled = false


func _on_reroll_pressed() -> void:
	if profile.reroll():
		_refresh_gacha()


func _on_upgrade_button_pressed() -> void:
	_refresh_upgrades()
	show_screen(upgrade_screen)


func _refresh_upgrades() -> void:
	currency_label.text = "Currency: %d" % profile.currency
	for key in RunProfile.UPGRADE_KEYS:
		var cost := profile.upgrade_cost(key)
		var entry: Dictionary = upgrade_buttons[key]
		var button: Button = entry.button
		button.text = "%s  Lv %d  —  %s" % [entry.label, profile.upgrades[key], "MAX" if cost < 0 else "%d currency" % cost]
		button.disabled = cost < 0 or profile.currency < cost


func _on_upgrade_pressed(key: String) -> void:
	profile.buy_upgrade(key)
	_refresh_upgrades()


func _on_ready_button_pressed() -> void:
	if not profile.run_active or profile.current_ball == null:
		return
	enemy_sprite.texture = boss_1_texture
	turn_manager.player_max_hp = 100 + 20 * int(profile.upgrades["hp"])
	turn_manager.enemy_max_hp = RunProfile.BOSSES[0]
	turn_manager.balls_left = profile.balls_left
	turn_manager.flat_damage = 5 * int(profile.upgrades["damage"])
	turn_manager.selected_ball = profile.current_ball
	pinball_table.set_ball_type(profile.current_ball)
	pinball_table.randomize_bumpers()
	show_screen(game_screen)
	turn_manager.start_battle()
	_update_battle_ui()


func _on_credits_button_pressed() -> void:
	show_screen(credit_screen)


func _on_exit_button_pressed() -> void:
	get_tree().quit()


func _on_back_button_pressed() -> void:
	if game_screen.visible and profile.run_active:
		profile.finish_run()
		_run_revision += 1
	show_screen(title_screen)


func _on_retry_button_pressed() -> void:
	profile.begin_run()
	_open_gacha()


func _on_damage_dealt(amount: int) -> void:
	if profile.run_active:
		profile.record_damage(amount)
		profile.balls_left = turn_manager.balls_left


func _on_battle_finished(player_won: bool) -> void:
	if not profile.run_active:
		return
	profile.balls_left = turn_manager.balls_left
	if player_won and profile.boss_index + 1 < RunProfile.BOSSES.size() and profile.balls_left > 0:
		_advance_boss_after_pause(_run_revision)
	else:
		profile.finish_run()
	_update_battle_ui()


func _advance_boss_after_pause(revision: int) -> void:
	await get_tree().create_timer(1.25).timeout
	if revision != _run_revision or not profile.run_active or not game_screen.visible:
		return
	profile.boss_index += 1
	if profile.boss_index == 1:
		enemy_sprite.texture = BOSS_2_TEXTURE
	turn_manager.start_next_opponent(RunProfile.BOSSES[profile.boss_index])
	_update_battle_ui()


func _on_battle_state_changed(state: TurnManager.BattleState) -> void:
	if state != TurnManager.BattleState.PREP and state != TurnManager.BattleState.BALL_IN_PLAY:
		pinball_table.stop_board()


func _update_battle_ui() -> void:
	enemy_health_bar.max_value = turn_manager.enemy_max_hp
	enemy_health_bar.value = turn_manager.enemy_hp
	player_health_bar.max_value = turn_manager.player_max_hp
	player_health_bar.value = turn_manager.player_hp
	enemy_hp_label.text = "Enemy HP: %d / %d" % [turn_manager.enemy_hp, turn_manager.enemy_max_hp]
	player_hp_label.text = "Your HP: %d / %d" % [turn_manager.player_hp, turn_manager.player_max_hp]
	score_label.text = "Score: %d\nHits: %d" % [turn_manager.turn_score, turn_manager.current_hits]
	if run_label != null:
		run_label.text = "Boss %d/%d  •  Balls: %d  •  %s\nEarned: %d currency" % [profile.boss_index + 1, RunProfile.BOSSES.size(), maxi(0, turn_manager.balls_left), profile.current_ball.display_name if profile.current_ball != null else "No type", profile.run_earned]
	retry_button.visible = not profile.run_active and turn_manager.current_state in [TurnManager.BattleState.VICTORY, TurnManager.BattleState.GAME_OVER]
	match turn_manager.current_state:
		TurnManager.BattleState.IDLE:
			battle_status.text = "Press Ready to start."
		TurnManager.BattleState.PREP:
			battle_status.text = "Turn %d\nHold Space / Enter, then release to launch." % (turn_manager.turn_number + 1)
		TurnManager.BattleState.BALL_IN_PLAY:
			if pinball_table.plunger._armed_ball == pinball_table.ball and pinball_table.ball.position.y >= 480.0:
				battle_status.text = "Ball back at plunger.\nHold Space / Enter, then release to relaunch."
			else:
				battle_status.text = "Turn %d  •  Charge +%d\nPress P at the charge to parry." % [turn_manager.turn_number, (turn_manager.charged_stacks - turn_manager.parried_stacks) * turn_manager.charge_bonus]
		TurnManager.BattleState.DAMAGE_CALCULATION:
			battle_status.text = "You deal %d damage!" % turn_manager.last_player_damage
		TurnManager.BattleState.ENEMY_PHASE:
			battle_status.text = "Enemy deals %d damage!" % turn_manager.last_enemy_damage
		TurnManager.BattleState.VICTORY:
			if profile.boss_index == RunProfile.BOSSES.size() - 1:
				battle_status.text = "Victory!"
			elif profile.run_active:
				battle_status.text = "Boss defeated! Next opponent incoming."
			else:
				battle_status.text = "Boss defeated, but no balls remain."
		TurnManager.BattleState.GAME_OVER:
			battle_status.text = "Defeat!\nYou dealt %d damage." % turn_manager.total_damage_dealt
