extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var board: PinballController = load("res://scenes/pinball/PinballTable.tscn").instantiate()
	root.add_child(board)
	await physics_frame
	var ball := board.ball
	var starts := [Vector2(110, 155), Vector2(200, 155), Vector2(250, 155), Vector2(340, 155), Vector2(430, 155)]
	var headings := [Vector2(-0.8, -1), Vector2(-0.5, -1), Vector2(0, -1), Vector2(0.5, -1), Vector2(0.8, -1)]
	for mask in [1, 2]:
		for start in starts:
			for heading in headings:
				ball.freeze = true
				ball.position = start
				ball.collision_mask = mask
				ball.linear_velocity = Vector2.ZERO
				PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, ball.global_transform)
				await physics_frame
				ball.freeze = false
				ball.linear_velocity = heading.normalized() * ball.max_linear_speed
				for frame in range(18):
					await physics_frame
					if ball.position.y < -5.0:
						failures += 1
						push_error("Ceiling escape with mask %d, start %s, heading %s, frame %d, position %s" % [mask, start, heading, frame, ball.position])
						break
	ball.freeze = true
	board.queue_free()
	await process_frame
	print("Ceiling regression: %d escape(s)." % failures)
	quit(1 if failures > 0 else 0)
