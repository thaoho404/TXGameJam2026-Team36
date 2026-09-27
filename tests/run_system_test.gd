extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	var profile := RunProfile.new()
	profile.save_path = "user://pin_roulette_regression_profile.json"
	profile.new_game()
	_check(profile.balls_left == 3 and profile.rerolls_left == 0 and profile.current_ball != null,
		"A new run starts with three balls and one rolled type")
	_check(not profile.reroll(), "No reroll is available before its permanent upgrade")
	profile.current_ball = GachaRoller.new().get_type("gold")
	_check(profile.record_damage(100) == 100 and profile.currency == 100,
		"Gold multiplies the 20 percent damage currency reward by five")
	_check(profile.buy_upgrade("balls") and profile.buy_upgrade("rerolls") and profile.buy_upgrade("hp"),
		"Currency purchases permanent upgrades")
	var saved_currency := profile.currency
	var loaded := RunProfile.new()
	loaded.save_path = profile.save_path
	loaded.load_profile()
	_check(loaded.currency == saved_currency and loaded.upgrades["balls"] == 1 and loaded.upgrades["rerolls"] == 1,
		"Currency and upgrades reload from the saved profile")
	loaded.begin_run()
	_check(loaded.balls_left == 4 and loaded.rerolls_left == 1 and loaded.reroll() and loaded.rerolls_left == 0,
		"Extra ball and reroll apply to the next run only")
	loaded.new_game()
	_check(loaded.currency == 0 and loaded.upgrades["balls"] == 0,
		"New Game resets showcase progression")

	var manager := TurnManager.new()
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	manager.balls_left = 2
	manager.selected_ball = GachaRoller.new().get_type("steel")
	root.add_child(manager)
	manager.start_battle()
	manager.on_ball_launched()
	_check(manager.balls_left == 1, "Launching consumes one inventory ball")
	manager.register_board_hit(BevoData.ElementType.STEEL, 10)
	_check(manager.turn_score == 100, "Steel on Steel uses the chart's tenfold score")
	manager.charged_stacks = 2
	manager.on_ball_drained()
	await create_timer(0.05).timeout
	_check(manager.player_hp == 88 and manager.last_enemy_damage == 12,
		"Steel reaction cancels charged bonus; Steel ball reduces base damage by 20 percent")
	manager.stop_battle()
	manager.queue_free()
	await process_frame

	manager = TurnManager.new()
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	manager.balls_left = 1
	root.add_child(manager)
	manager.start_battle()
	manager.on_ball_launched()
	manager.on_ball_drained()
	await create_timer(0.12).timeout
	_check(manager.current_state == TurnManager.BattleState.GAME_OVER and manager.balls_left == 0,
		"An empty ball inventory ends the run after retaliation")
	manager.queue_free()
	await process_frame

	manager = TurnManager.new()
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	manager.balls_left = 2
	root.add_child(manager)
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.GHOST, 10)
	manager.charged_stacks = 1
	manager.on_ball_drained()
	await create_timer(0.05).timeout
	_check(manager.player_hp == 100, "Ghost target grants a guaranteed dodge on the next attack")
	manager.stop_battle()
	manager.queue_free()
	await process_frame

	manager = TurnManager.new()
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	manager.balls_left = 2
	root.add_child(manager)
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.WIND, 10)
	manager.register_board_hit(BevoData.ElementType.WIND, 10)
	manager.register_board_hit(BevoData.ElementType.ICE, 10)
	_check(is_equal_approx(manager.ball_speed_multiplier, 1.2),
		"Wind and Ice speed changes stack until drain")
	manager.charged_stacks = 1
	manager._parry_window_remaining = 0.2
	_check(manager.try_parry() and manager.parried_stacks == 1 and not manager.try_parry(),
		"A timed manual parry cancels one charge only")
	manager.on_ball_drained()
	await create_timer(0.12).timeout
	_check(manager.player_hp == 85 and is_equal_approx(manager.ball_speed_multiplier, 1.0),
		"Parried charge adds no damage and speed resets on drain")
	manager.stop_battle()
	manager.queue_free()
	await process_frame

	manager = TurnManager.new()
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	manager.balls_left = 2
	manager.selected_ball = GachaRoller.new().get_type("electric")
	root.add_child(manager)
	manager.start_battle()
	manager.on_ball_launched()
	manager.register_board_hit(BevoData.ElementType.FIRE, 10)
	_check(manager.turn_score == 40 and is_equal_approx(manager.selected_ball.speed_multiplier, 1.4),
		"Electric strengthens a 3x reaction to 4x and starts 1.4x faster")
	manager.register_board_hit(BevoData.ElementType.PSYCHIC, 10)
	manager.on_ball_drained()
	await create_timer(0.12).timeout
	_check(manager.enemy_hp == 147 and manager.player_hp == 85,
		"Psychic target causes 20 percent of the enemy attack to hit itself")
	manager.stop_battle()
	manager.queue_free()
	await process_frame
	print("Run system checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures > 0 else 0)
