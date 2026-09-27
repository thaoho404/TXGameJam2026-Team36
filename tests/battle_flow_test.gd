extends SceneTree

# Run from the project folder:
# Godot.exe --headless --path . --script res://tests/battle_flow_test.gd
var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_turn_resolution()
	await _test_empty_turn()
	await _test_victory()
	await _test_player_death()
	await _test_cancelled_player_attack()
	await _test_cancelled_enemy_phase()
	await _test_main_scene()
	print("Battle regression checks: %d passed, %d failed." % [_checks - _failures, _failures])
	quit(1 if _failures > 0 else 0)


func _new_manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.player_max_hp = 100
	manager.enemy_max_hp = 200
	manager.enemy_base_damage = 15
	manager.player_attack_delay = 0.02
	manager.enemy_attack_delay = 0.02
	root.add_child(manager)
	return manager


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("PASS: " + description)
	else:
		_failures += 1
		push_error("FAIL: " + description)


func _wait_for_state(manager: TurnManager, expected: TurnManager.BattleState) -> bool:
	for _attempt in range(60):
		if manager.current_state == expected:
			return true
		await create_timer(0.01).timeout
	return false


func _remove_manager(manager: TurnManager) -> void:
	manager.stop_battle()
	manager.queue_free()
	await process_frame


func _test_turn_resolution() -> void:
	var manager := _new_manager()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	_check(manager.turn_score == 0, "Idle board hits cannot score")
	manager.start_battle()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	_check(manager.turn_score == 0, "Hits before launching cannot score")
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 35)
	manager.register_board_hit(BevoData.ElementType.NORMAL, 25)
	manager.register_board_hit(BevoData.ElementType.NORMAL, 0)
	manager.register_board_hit(BevoData.ElementType.NORMAL, -10)
	_check(manager.turn_score == 60 and manager.current_hits == 2,
		"Active hits accumulate points; zero and negative awards are ignored")
	_check(manager.enemy_hp == 200, "Enemy HP stays unchanged until the ball drains")
	manager.on_ball_drained()
	_check(manager.enemy_hp == 140 and manager.last_player_damage == 60,
		"Draining applies the whole final score once")
	_check(manager.player_hp == 100, "Player damage resolves before enemy retaliation")
	manager.on_ball_drained()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	manager.on_ball_launched()
	_check(manager.enemy_hp == 140 and manager.turn_score == 60 and manager.turn_number == 1,
		"Resolution ignores duplicate drain, score, and launch events")
	var ready := await _wait_for_state(manager, TurnManager.BattleState.PREP)
	_check(ready and manager.player_hp == 85 and manager.enemy_hp == 140,
		"Surviving enemy retaliates exactly once before the next ball")
	_check(manager.turn_score == 0 and manager.current_hits == 0 and manager.total_damage_dealt == 60,
		"Next turn clears its score and preserves accumulated damage")
	await _remove_manager(manager)


func _test_empty_turn() -> void:
	var manager := _new_manager()
	manager.start_battle()
	manager.on_ball_launched()
	manager.on_ball_drained()
	var ready := await _wait_for_state(manager, TurnManager.BattleState.PREP)
	_check(ready and manager.enemy_hp == 200 and manager.player_hp == 85,
		"A zero-score drain still gives the enemy its attack")
	await _remove_manager(manager)


func _test_victory() -> void:
	var manager := _new_manager()
	var results: Array[bool] = []
	manager.battle_finished.connect(func(won: bool) -> void: results.append(won))
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 250)
	manager.on_ball_drained()
	var won := await _wait_for_state(manager, TurnManager.BattleState.VICTORY)
	manager.on_ball_drained()
	_check(won and manager.enemy_hp == 0 and manager.player_hp == 100,
		"A lethal player turn wins without enemy retaliation")
	_check(manager.last_player_damage == 200 and manager.total_damage_dealt == 200,
		"Recorded damage excludes overkill and HP never goes negative")
	_check(results.size() == 1 and results[0], "Victory emits one successful battle result")
	await _remove_manager(manager)


func _test_player_death() -> void:
	var manager := _new_manager()
	manager.player_max_hp = 10
	var serves: Array[int] = [0]
	var results: Array[bool] = []
	manager.turn_ready.connect(func() -> void: serves[0] += 1)
	manager.battle_finished.connect(func(won: bool) -> void: results.append(won))
	manager.start_battle()
	manager.on_ball_launched()
	manager.on_ball_drained()
	var lost := await _wait_for_state(manager, TurnManager.BattleState.GAME_OVER)
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	_check(lost and manager.player_hp == 0 and manager.last_enemy_damage == 10,
		"Lethal enemy attack clamps player HP and ends the battle")
	_check(serves[0] == 1 and manager.current_state == TurnManager.BattleState.GAME_OVER,
		"Death does not serve another ball and ignores further launches")
	_check(results.size() == 1 and not results[0] and manager.turn_score == 0,
		"Defeat emits one result and blocks further scoring")
	await _remove_manager(manager)


func _test_cancelled_player_attack() -> void:
	var manager := _new_manager()
	manager.player_attack_delay = 0.08
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	manager.on_ball_drained()
	manager.stop_battle()
	await create_timer(0.12).timeout
	_check(manager.current_state == TurnManager.BattleState.IDLE and manager.player_hp == 100,
		"Leaving during the player attack cancels delayed retaliation")
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 50)
	manager.on_ball_drained()
	manager.stop_battle()
	manager.start_battle()
	await create_timer(0.12).timeout
	_check(manager.player_hp == 100 and manager.enemy_hp == 200 and manager.turn_number == 0
		and manager.current_state == TurnManager.BattleState.PREP,
		"Old player-attack timer cannot damage or advance a fresh battle")
	await _remove_manager(manager)


func _test_cancelled_enemy_phase() -> void:
	var manager := _new_manager()
	manager.enemy_attack_delay = 0.10
	var serves: Array[int] = [0]
	manager.turn_ready.connect(func() -> void: serves[0] += 1)
	manager.start_battle()
	manager.on_ball_launched()
	manager.on_ball_drained()
	var retaliated := await _wait_for_state(manager, TurnManager.BattleState.ENEMY_PHASE)
	_check(retaliated and manager.player_hp == 85, "Enemy phase begins after retaliation")
	manager.stop_battle()
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.NORMAL, 7)
	await create_timer(0.15).timeout
	_check(manager.current_state == TurnManager.BattleState.BALL_IN_PLAY and manager.turn_score == 7
		and manager.player_hp == 100 and serves[0] == 2,
		"Old enemy-phase timer cannot clear a fresh turn or serve an extra ball")
	await _remove_manager(manager)


func _test_main_scene() -> void:
	var scene := load("res://scenes/ui/Main.tscn") as PackedScene
	_check(scene != null, "Main scene loads")
	if scene == null:
		return
	var main := scene.instantiate() as Control
	root.add_child(main)
	await process_frame
	var manager: TurnManager = main.turn_manager
	var board: PinballController = main.pinball_table
	var bumper := board.get_node("Bumpers/Bumper1")
	manager.player_attack_delay = 0.03
	manager.enemy_attack_delay = 0.03
	_check(main.title_screen.visible and not main.game_screen.visible
		and manager.current_state == TurnManager.BattleState.IDLE
		and board.board_state == PinballController.BoardState.STOPPED,
		"Main opens on the title with combat and board stopped")
	_check(not board.plunger.request_launch(2000.0) and board.ball.freeze,
		"Hidden board cannot launch from the title menu")
	main.get_node("MainMenu/Panel/PlayButton").pressed.emit()
	_check(main.start_screen.visible and not main.game_screen.visible
		and board.board_state == PinballController.BoardState.STOPPED,
		"Play button opens New Game / Continue without starting the board")
	main._on_continue_pressed()
	_check(main.gacha_screen.visible and main.profile.current_ball != null,
		"Continue rolls a ball before the run")
	var scene_reroll: Button = main.get_node("MainMenu/GachaMenu/Panel/GachaContent/RerollButton")
	_check(scene_reroll.owner == main and main.roll_label.owner == main,
		"Gacha controls are editable scene nodes")
	main.profile.rerolls_left = 1
	main._refresh_gacha()
	scene_reroll.pressed.emit()
	_check(main.profile.rerolls_left == 0 and scene_reroll.disabled
		and main.profile.current_ball.display_name in main.roll_label.text,
		"Scene reroll button updates the selected ball and remaining rerolls")
	main.profile.current_ball = GachaRoller.new().get_type("normal")
	main._refresh_gacha()
	main.get_node("MainMenu/GachaMenu/Panel/ReadyButton").pressed.emit()
	await process_frame
	_check(main.game_screen.visible and not main.gacha_screen.visible
		and manager.current_state == TurnManager.BattleState.PREP
		and board.board_state == PinballController.BoardState.READY,
		"Ready button starts combat and serves a ball")
	_check(main.enemy_health_bar.value == manager.enemy_max_hp
		and main.player_health_bar.value == manager.player_max_hp
		and "Score: 0" in main.score_label.text,
		"Ready initializes both HP bars and score text")
	_check(board.plunger.request_launch(2000.0)
		and manager.current_state == TurnManager.BattleState.BALL_IN_PLAY,
		"Real plunger launch starts the combat turn through its signal")
	# Inject a contact notification to exercise the actual connected board signal.
	# Physical ball trajectories are deliberately excluded from this deterministic test.
	board.ball.body_entered.emit(bumper)
	board.ball.body_entered.emit(bumper)
	var reaction := ReactionTable.new().get_reaction(board._bumper_types[bumper], manager.selected_ball.element)
	var strength: float = manager.selected_ball.reaction_strength_mult
	var multiplier: float = reaction.multiplier
	if strength > 1.0:
		multiplier = maxf(0.0, 1.0 + (multiplier - 1.0) * strength)
	var expected_score: int = 2 * roundi(board.bumper_points * multiplier * manager.selected_ball.score_currency_multiplier)
	_check(manager.turn_score == expected_score
		and ("Score: %d" % expected_score) in main.score_label.text,
		"Bumper contact signals update turn score and live score text")
	board._on_drain_zone_body_entered(board.ball)
	board._on_drain_zone_body_entered(board.ball)
	_check(manager.enemy_hp == manager.enemy_max_hp - expected_score
		and main.enemy_health_bar.value == manager.enemy_hp,
		"Board drain signal applies damage once and updates the enemy bar")
	_check(board.board_state == PinballController.BoardState.STOPPED
		and not board.plunger.request_launch(2000.0),
		"Board waits for combat resolution before another launch")
	var ready := await _wait_for_state(manager, TurnManager.BattleState.PREP)
	await process_frame
	_check(ready and main.player_health_bar.value == manager.player_max_hp - manager.enemy_base_damage
		and board.board_state == PinballController.BoardState.READY,
		"Retaliation updates player HP and combat serves the next ball")
	_check("Score: 0" in main.score_label.text and "Turn 2" in main.battle_status.text,
		"Next ball shows a cleared score and the next turn number")
	manager.enemy_hp = 1
	board.plunger.request_launch(2000.0)
	board.ball.body_entered.emit(bumper)
	manager.turn_score = maxi(1, manager.turn_score)
	board._on_drain_zone_body_entered(board.ball)
	var won := await _wait_for_state(manager, TurnManager.BattleState.VICTORY)
	_check(won and not main.retry_button.visible and "Boss defeated!" in main.battle_status.text
		and board.board_state == PinballController.BoardState.STOPPED,
		"First boss defeat pauses before the next opponent")
	await create_timer(1.3).timeout
	_check(main.profile.boss_index == 1 and manager.enemy_hp == 1000 and manager.player_hp == 85
		and manager.balls_left == 1 and board.board_state == PinballController.BoardState.READY,
		"Second boss starts at 1000 HP with remaining balls and player HP carried forward")
	board.plunger.request_launch(2000.0)
	manager.turn_score = 1000
	board._on_drain_zone_body_entered(board.ball)
	var final_win := await _wait_for_state(manager, TurnManager.BattleState.VICTORY)
	_check(final_win and main.retry_button.visible and "Victory!" in main.battle_status.text,
		"Defeating the final boss completes the run even when the last ball was spent")
	main.retry_button.pressed.emit()
	_check(main.gacha_screen.visible and manager.current_state == TurnManager.BattleState.IDLE,
		"Retry button returns to gacha and stops the completed battle")
	main.get_node("MainMenu/GachaMenu/Panel/ReadyButton").pressed.emit()
	await process_frame
	board.plunger.request_launch(2000.0)
	board._on_drain_zone_body_entered(board.ball)
	main._on_back_button_pressed()
	await create_timer(0.12).timeout
	_check(main.title_screen.visible and manager.current_state == TurnManager.BattleState.IDLE
		and board.board_state == PinballController.BoardState.STOPPED
		and manager.player_hp == manager.player_max_hp,
		"Leaving gameplay during damage resolution cancels pending retaliation")
	main.queue_free()
	await process_frame
