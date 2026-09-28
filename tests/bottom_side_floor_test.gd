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


func _drop_ball(board: PinballController, start: Vector2, mask: int, speed: float, left_side: bool) -> bool:
	var ball := board.ball
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.position = start
	ball.collision_mask = mask
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, ball.global_transform)
	await physics_frame
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = Vector2.DOWN * speed
	for frame in range(24):
		await physics_frame
		if ball.position.y > 650.0 and (ball.position.x < 190.0 if left_side else ball.position.x > 350.0):
			return true
	return false


func _run() -> void:
	for check in [
		[Vector2(30, 548), 1, 1200.0, true],
		[Vector2(30, 548), 2, 1200.0, true],
		[Vector2(30, 548), 1, 3200.0, true],
		[Vector2(30, 548), 2, 3200.0, true],
		[Vector2(450, 548), 1, 1200.0, false],
		[Vector2(450, 548), 2, 1200.0, false],
		[Vector2(450, 548), 2, 3200.0, false],
	]:
		var board: PinballController = load("res://scenes/pinball/PinballTable.tscn").instantiate()
		root.add_child(board)
		board.prepare_next_ball()
		await physics_frame
		await physics_frame
		var passed_through := await _drop_ball(board, check[0], check[1], check[2], check[3])
		_check(not passed_through, "%s lower edge contains a %d-speed ball on mask %d" % ["Left" if check[3] else "Right", int(check[2]), check[1]])
		board.queue_free()
		await process_frame

	var center_board: PinballController = load("res://scenes/pinball/PinballTable.tscn").instantiate()
	root.add_child(center_board)
	center_board.prepare_next_ball()
	await physics_frame
	await physics_frame
	center_board.ball.freeze = true
	center_board.ball.position = Vector2(287, 620)
	center_board.ball.linear_velocity = Vector2.ZERO
	PhysicsServer2D.body_set_state(center_board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, center_board.ball.global_transform)
	await physics_frame
	center_board.ball.freeze = false
	center_board.ball.linear_velocity = Vector2.DOWN * 1200.0
	for frame in range(24):
		await physics_frame
		if center_board.ball.position.y > 675.0:
			break
	_check(center_board.ball.position.y > 675.0, "Center drain remains open")
	center_board.queue_free()
	await process_frame

	for side in [
		["left", Vector2(120, 470)],
		["right", Vector2(412, 470)],
	]:
		var rail_board: PinballController = load("res://scenes/pinball/PinballTable.tscn").instantiate()
		root.add_child(rail_board)
		rail_board.prepare_next_ball()
		await physics_frame
		await physics_frame
		for bumper in rail_board.get_node("Bumpers").get_children():
			bumper.collision_layer = 0
		for spring in [rail_board.get_node("LeftSpringBumper"), rail_board.get_node("RightSpringBumper")]:
			spring.collision_layer = 0
		for flipper in rail_board.get_node("Flippers").get_children():
			flipper.collision_layer = 0
		rail_board.board_state = PinballController.BoardState.IN_PLAY
		rail_board.plunger.disarm()
		rail_board.ball.freeze = true
		rail_board.ball.position = side[1]
		rail_board.ball.linear_velocity = Vector2.ZERO
		PhysicsServer2D.body_set_state(rail_board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, rail_board.ball.global_transform)
		await physics_frame
		rail_board.ball.freeze = false
		rail_board.ball.linear_velocity = Vector2.DOWN * 700.0
		var rebounded := false
		for frame in range(24):
			await physics_frame
			if rail_board.ball.linear_velocity.y < -150.0:
				rebounded = true
				break
		_check(rebounded, "%s yellow border rebounds a falling ball" % side[0].capitalize())
		rail_board.queue_free()
		await process_frame

	for start in [Vector2(30, 548), Vector2(450, 548)]:
		var corner_board: PinballController = load("res://scenes/pinball/PinballTable.tscn").instantiate()
		root.add_child(corner_board)
		corner_board.prepare_next_ball()
		await physics_frame
		await physics_frame
		corner_board.board_state = PinballController.BoardState.IN_PLAY
		corner_board.plunger.disarm()
		corner_board.ball.freeze = true
		corner_board.ball.position = start
		corner_board.ball.linear_velocity = Vector2.ZERO
		PhysicsServer2D.body_set_state(corner_board.ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, corner_board.ball.global_transform)
		await physics_frame
		corner_board.ball.freeze = false
		corner_board.ball.linear_velocity = Vector2.DOWN * 1200.0
		var returned_to_playfield := false
		for frame in range(180):
			await physics_frame
			if corner_board.ball.position.distance_to(corner_board.launch_lane_rescue_position) < 50.0:
				returned_to_playfield = true
				break
		var drained := corner_board.board_state == PinballController.BoardState.STOPPED
		var rolled_into_playfield := corner_board.ball.position.x >= 175.0 and corner_board.ball.position.x <= 400.0
		var bounced_above_guard := corner_board.ball.position.y < 500.0 and corner_board.ball.linear_velocity.length() > 100.0
		_check(returned_to_playfield or drained or rolled_into_playfield or bounced_above_guard,
			"Ball cannot remain trapped on the %s lower guard" % ("left" if start.x < 200 else "right"))
		corner_board.queue_free()
		await process_frame
	print("Bottom side floor: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
