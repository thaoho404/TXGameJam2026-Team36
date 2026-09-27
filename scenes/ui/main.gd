extends Control

@onready var title_screen: Control = $MainMenu/Panel
@onready var upgrade_screen: Control = $MainMenu/UpgradeMenu
@onready var gacha_screen: Control = $MainMenu/GachaMenu
@onready var credit_screen: Control = $MainMenu/CreditMenu
@onready var game_screen: Control = $MainMenu/GamePlay
@onready var turn_manager: TurnManager = $TurnManager
@onready var pinball_table: PinballController = $MainMenu/GamePlay/HBoxContainer/PinballBoard/SubViewport/PinballTable
@onready var combat_ui: Control = $MainMenu/GamePlay/HBoxContainer/CombatUI
@onready var enemy_health_bar: TextureProgressBar = combat_ui.get_node("EnemyHealthBar")
@onready var player_health_bar: TextureProgressBar = combat_ui.get_node("PlayerHealthBar")
@onready var enemy_hp_label: Label = combat_ui.get_node("EnemyHPLabel")
@onready var player_hp_label: Label = combat_ui.get_node("PlayerHPLabel")
@onready var score_label: Label = combat_ui.get_node("ScorePanel/ScoreLabel")
@onready var battle_status: Label = combat_ui.get_node("DialogueBox/BattleStatus")
@onready var retry_button: Button = combat_ui.get_node("RetryButton")

func _ready() -> void:
	pinball_table.ball_launched.connect(turn_manager.on_ball_launched)
	pinball_table.bumper_hit.connect(turn_manager.register_board_hit)
	pinball_table.ball_drained.connect(turn_manager.on_ball_drained)
	turn_manager.turn_ready.connect(pinball_table.prepare_next_ball)
	turn_manager.state_changed.connect(_on_battle_state_changed)
	turn_manager.battle_updated.connect(_update_battle_ui)
	show_screen(title_screen)
	_update_battle_ui()

func show_screen(screen: Control) -> void:
	if screen != game_screen:
		turn_manager.stop_battle()
		pinball_table.stop_board()
	title_screen.hide()
	upgrade_screen.hide()
	gacha_screen.hide()
	credit_screen.hide()
	game_screen.hide()
	screen.show()
	get_viewport().gui_release_focus()

func _on_play_button_pressed() -> void:
	show_screen(gacha_screen)

func _on_upgrade_button_pressed() -> void:
	show_screen(upgrade_screen)

func _on_ready_button_pressed() -> void:
	show_screen(game_screen)
	turn_manager.start_battle()

func _on_credits_button_pressed() -> void:
	show_screen(credit_screen)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	show_screen(title_screen)


func _on_retry_button_pressed() -> void:
	show_screen(gacha_screen)


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
	retry_button.visible = turn_manager.current_state in [TurnManager.BattleState.VICTORY, TurnManager.BattleState.GAME_OVER]

	match turn_manager.current_state:
		TurnManager.BattleState.IDLE:
			battle_status.text = "Press Ready to start."
		TurnManager.BattleState.PREP:
			battle_status.text = "Turn %d\nHold Space / Enter, then release to launch." % (turn_manager.turn_number + 1)
		TurnManager.BattleState.BALL_IN_PLAY:
			battle_status.text = "Turn %d\nLeft / Right arrows control flippers." % turn_manager.turn_number
		TurnManager.BattleState.DAMAGE_CALCULATION:
			battle_status.text = "You deal %d damage!" % turn_manager.last_player_damage
		TurnManager.BattleState.ENEMY_PHASE:
			battle_status.text = "Enemy deals %d damage!" % turn_manager.last_enemy_damage
		TurnManager.BattleState.VICTORY:
			battle_status.text = "Victory!\nOpponent defeated in %d turns." % turn_manager.turn_number
		TurnManager.BattleState.GAME_OVER:
			battle_status.text = "Defeat!\nYou dealt %d damage." % turn_manager.total_damage_dealt
