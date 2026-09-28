extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, description: String) -> void:
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func _wheel(name: String, position: Vector2) -> StaticBody2D:
	var wheel := StaticBody2D.new()
	wheel.name = name
	wheel.position = position
	var material := PhysicsMaterial.new()
	material.bounce = 1.6
	wheel.physics_material_override = material
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	collision.shape = circle
	wheel.add_child(collision)
	return wheel


func _run() -> void:
	var table := Node2D.new()
	var bumpers := Node2D.new()
	bumpers.name = "Bumpers"
	table.add_child(bumpers)
	var left := _wheel("BumperWheelLeft", Vector2(186, 485))
	var right := _wheel("BumperWheelRight", Vector2(359, 485))
	bumpers.add_child(left)
	bumpers.add_child(right)
	var ball: RigidBody2D = load("res://scenes/pinball/BevoBall.tscn").instantiate()
	ball.gravity_scale = 0.0
	ball.position = Vector2(445, 485)
	table.add_child(ball)
	root.add_child(table)
	await physics_frame
	ball.linear_velocity = Vector2(-600, 0)
	for frame in range(16):
		await physics_frame
	_check(ball.linear_velocity.x > 100.0 and absf(ball.linear_velocity.y) < 100.0,
		"Right wheel side hit reflects outward without an upward launch")
	_check(int(ball.get("_last_wheel_escape_ms")) < 0,
		"A single side hit does not trigger wheel escape")

	# Simulate rapid alternating contacts at the two inner wheel faces.
	ball.freeze = true
	ball.position = Vector2(286, 485)
	ball._on_body_entered(right)
	_check(int(ball.get("_last_wheel_escape_ms")) < 0,
		"First inner contact keeps the normal bounce")
	ball.position = Vector2(259, 485)
	ball._on_body_entered(left)
	_check(int(ball.get("_last_wheel_escape_ms")) < 0,
		"Second inner contact keeps the normal bounce")
	ball.position = Vector2(286, 485)
	ball.freeze = false
	ball.linear_velocity = Vector2(300, 0)
	ball._on_body_entered(right)
	await physics_frame
	_check(int(ball.get("_last_wheel_escape_ms")) > 0
		and absf(ball.linear_velocity.x) < 1.0 and ball.linear_velocity.y < -100.0,
		"Repeated contacts in the center pocket escape straight upward")

	table.queue_free()
	await process_frame
	print("Wheel collision checks: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
