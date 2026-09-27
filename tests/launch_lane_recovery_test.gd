extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _place_stuck_ball(board: PinballController, point: Vector2) -> void:
	board.ball.freeze = true
	board.ball.linear_velocity = Vector2.ZERO
	board.ball.position = point
	PhysicsServer2D.body_set_state(board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, board.ball.global_transform)
	board.plunger.disarm()


func _run() -> void:
	var main: Control = load("res://scenes/ui/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main._on_continue_pressed()
	main.profile.current_ball = GachaRoller.new().get_type("normal")
	main._on_ready_button_pressed()
	await physics_frame
	await physics_frame
	var board: PinballController = main.pinball_table
	var manager: TurnManager = main.turn_manager
	board.launch_lane_stall_seconds = 0.2
	board.launch_lane_max_seconds = 0.6
	_check(board.plunger.request_launch(2000.0), "Initial launch succeeds")
	var stock := manager.balls_left
	var turn := manager.turn_number

	_place_stuck_ball(board, Vector2(535, 300))
	await create_timer(0.3).timeout
	_check(board.ball.position.distance_to(board.launch_lane_rescue_position) < 80.0
		and board.ball.get_collision_mask_value(1) and not board.ball.get_collision_mask_value(2),
		"Wedged ball high in the launch lane returns to the playfield")
	_check(board.board_state == PinballController.BoardState.IN_PLAY
		and manager.balls_left == stock and manager.turn_number == turn,
		"Recovery keeps the same turn and ball inventory")

	_place_stuck_ball(board, Vector2(535, 510))
	await create_timer(0.3).timeout
	_check(board.plunger._armed_ball == board.ball and board.ball.position.distance_to(board.spawn_position) < 35.0,
		"Wedged ball near the plunger is rearmed for another launch")
	_check("relaunch" in main.battle_status.text.to_lower(), "Combat UI explains how to relaunch")
	await create_timer(0.3).timeout
	_check(board.plunger._armed_ball == board.ball and board.ball.position.distance_to(board.spawn_position) < 35.0,
		"A ball waiting for player input is not mistaken for a stuck ball")
	_check(board.plunger.request_launch(1000.0) and manager.balls_left == stock and manager.turn_number == turn,
		"Relaunching the rescued ball does not spend a second inventory ball")
	main.queue_free()
	await process_frame
	print("Launch lane recovery: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
