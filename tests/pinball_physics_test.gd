extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _run() -> void:
	var main: Control = load("res://scenes/ui/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	main._on_continue_pressed()
	main.profile.current_ball = GachaRoller.new().get_type("normal")
	main.get_node("MainMenu/GachaMenu/Panel/ReadyButton").pressed.emit()
	await physics_frame
	await physics_frame
	var board: PinballController = main.get_node("MainMenu/GamePlay/HBoxContainer/PinballBoard/SubViewport/PinballTable")
	for bumper in board.get_node("Bumpers").get_children():
		board._bumper_types[bumper] = BevoData.ElementType.NORMAL
	var manager: TurnManager = main.get_node("TurnManager")
	manager.player_attack_delay = 0.01
	manager.enemy_attack_delay = 0.01
	_check(board.board_state == PinballController.BoardState.READY, "First ball is ready")
	_check(board.plunger.request_launch(2000.0), "First ball launches")
	for frame in range(10):
		await physics_frame
	_check(board.ball.position.y < board.spawn_position.y - 150.0, "First ball travels up the launch lane")

	board._on_drain_zone_body_entered(board.ball)
	for frame in range(60):
		await physics_frame
		if board.board_state == PinballController.BoardState.READY:
			break
	var physics_position: Vector2 = PhysicsServer2D.body_get_state(board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM).origin
	_check(board.board_state == PinballController.BoardState.READY, "Combat serves a second ball")
	_check(board.ball.global_position.distance_to(physics_position) < 0.01,
		"Second ball's visible and physics positions match")
	_check(board.plunger.request_launch(2000.0), "Second ball launches")
	for frame in range(10):
		await physics_frame
	_check(board.board_state == PinballController.BoardState.IN_PLAY
		and board.ball.position.y < board.spawn_position.y - 150.0,
		"Second ball travels up the launch lane")

	# A ball still using the ramp collision mask must not fall through the gate.
	board.ball.freeze = true
	board.ball.position = Vector2(535, 115)
	PhysicsServer2D.body_set_state(board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, board.ball.global_transform)
	board.ball.collision_mask = 2
	board.ball.freeze = false
	board.ball.linear_velocity = Vector2(0, 300)
	var lowest_y: float = board.ball.position.y
	for frame in range(28):
		await physics_frame
		lowest_y = maxf(lowest_y, board.ball.position.y)
	_check(board.get_node("LaunchGate").collision_layer & 2 != 0
		and lowest_y < 180.0, "Launch gate blocks a returning ball on the ramp collision layer")

	var score_before_springs: int = manager.turn_score
	var spring_checks := [
		["LeftSpringBumper", Vector2(92, 474), Vector2(-400, 200)],
		["RightSpringBumper", Vector2(398, 453), Vector2(400, 200)]
	]
	for spring_check in spring_checks:
		var spring: StaticBody2D = board.get_node(spring_check[0])
		board.ball.freeze = true
		board.ball.position = spring_check[1]
		PhysicsServer2D.body_set_state(board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, board.ball.global_transform)
		board.ball.collision_mask = 1
		board.ball.freeze = false
		board.ball.linear_velocity = spring_check[2]
		for frame in range(3):
			await physics_frame
		_check(int(spring.get("_last_kick_ms")) > 0
			and board.ball.linear_velocity.dot(spring.kick_direction) > 0.0,
			"%s pushes the ball toward the playfield" % spring_check[0])
	_check(manager.turn_score == score_before_springs,
		"Spring bumper contacts do not award elemental points")

	# A fast rebound near the upper bumper previously escaped through the ceiling.
	board.ball.freeze = true
	board.ball.position = Vector2(250, 150)
	PhysicsServer2D.body_set_state(board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, board.ball.global_transform)
	board.ball.collision_mask = 1
	board.ball.freeze = false
	board.ball.linear_velocity = Vector2(-300, -5000)
	var highest_speed: float = 0.0
	var highest_position: float = board.ball.position.y
	for frame in range(100):
		await physics_frame
		highest_speed = maxf(highest_speed, board.ball.linear_velocity.length())
		highest_position = minf(highest_position, board.ball.position.y)
	_check(highest_speed <= board.ball.max_linear_speed + 1.0 and highest_position >= 0.0,
		"Fast bumper rebound remains inside the visible upper boundary")

	var target: StaticBody2D = load("res://scenes/pinball/DropTarget.tscn").instantiate()
	root.add_child(target)
	var target_ball: RigidBody2D = load("res://scenes/pinball/BevoBall.tscn").instantiate()
	target_ball.freeze = true
	target_ball.position = target.position
	root.add_child(target_ball)
	target._on_hitbox_body_entered(target_ball)
	await physics_frame
	await physics_frame
	await create_timer(5.2).timeout
	_check(target.is_dropped and target.get_node("SolidWall").disabled,
		"Drop target stays down while the ball overlaps its wall")
	target_ball.position = Vector2(200, 200)
	PhysicsServer2D.body_set_state(target_ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, target_ball.global_transform)
	await physics_frame
	await physics_frame
	await process_frame
	_check(not target.is_dropped and not target.get_node("SolidWall").disabled,
		"Drop target rises after the ball leaves")
	print("Pinball physics checks: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
