extends RigidBody2D

@export_range(100.0, 10000.0, 100.0) var max_linear_speed: float = 3200.0
<<<<<<< HEAD
@export_range(0.0, 1000.0, 25.0) var wheel_escape_impulse: float = 650.0
@export_range(0.0, 200.0, 5.0) var stall_speed: float = 55.0
@export_range(0.1, 5.0, 0.05) var stall_seconds: float = 0.4
@export_range(0.0, 1000.0, 25.0) var stall_escape_speed: float = 480.0

var _last_wheel_escape_ms: int = -1000000
var _stall_elapsed: float = 0.0
=======
var _roof_points := PackedVector2Array()
var _ball_radius: float = 25.0
>>>>>>> 29a4018526ca3f538e26ed751e276994085adad5


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Fast bumper and target rebounds can push the ball through the thin edge
	# of the table in a single physics step.
	if state.linear_velocity.length_squared() > max_linear_speed * max_linear_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_linear_speed)
	# CCD can still miss a sloped roof after a very fast rebound.
	_keep_inside_roof(state)


func _keep_inside_roof(state: PhysicsDirectBodyState2D) -> void:
	if _roof_points.size() < 2 or not get_parent() is Node2D:
		return
	var table := get_parent() as Node2D
	var local_position := table.to_local(state.transform.origin)
	if local_position.x < _roof_points[0].x or local_position.x > _roof_points[-1].x:
		return
	for index in range(_roof_points.size() - 1):
		var start: Vector2 = _roof_points[index]
		var finish: Vector2 = _roof_points[index + 1]
		if local_position.x > finish.x:
			continue
		var roof_y := lerpf(start.y, finish.y, (local_position.x - start.x) / (finish.x - start.x))
		var minimum_y := roof_y + _ball_radius + 1.0
		if local_position.y < minimum_y:
			local_position.y = minimum_y
			var corrected := state.transform
			corrected.origin = table.to_global(local_position)
			state.transform = corrected
			var inward_normal := Vector2(start.y - finish.y, finish.x - start.x).normalized()
			if state.linear_velocity.dot(inward_normal) < 0.0:
				state.linear_velocity = state.linear_velocity.bounce(inward_normal) * 0.8
		break

	# Recover from shallow collider pockets without interfering with the plunger lane.
	if global_position.x < 490.0 and state.linear_velocity.length() < stall_speed:
		_stall_elapsed += state.step
		if _stall_elapsed >= stall_seconds:
			var horizontal_sign := 1.0 if global_position.x < 287.0 else -1.0
			state.linear_velocity = Vector2(horizontal_sign * 0.45, -1.0).normalized() * stall_escape_speed
			_stall_elapsed = 0.0
	else:
		_stall_elapsed = 0.0


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 3
	var shape := $CollisionShape2D.shape as CircleShape2D
	if shape != null:
		_ball_radius = shape.radius
	var shell := get_parent().get_node_or_null("StaticEnvironment/OuterShell") as CollisionPolygon2D
	if shell != null:
		for index in range(mini(6, shell.polygon.size())):
			_roof_points.append(shell.polygon[index])
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name.begins_with("Bumper"):
		print("Hit ", body.name)
		if body.name.begins_with("BumperWheel"):
			_kick_out_of_lower_wheels(body)
		var sprite := body.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.modulate = Color(2, 2, 2) 
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)


func _kick_out_of_lower_wheels(wheel: Node2D) -> void:
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_wheel_escape_ms < 180:
		return
	_last_wheel_escape_ms = now_ms

	# Push up and away from the narrow center pocket between the two wheels.
	# Clearing this in one shot matters: with bounce > 1 on the wheels, a weak
	# kick just lets the ball ping-pong back and forth between them instead of
	# escaping, which is what "getting stuck" actually looks like here.
	var horizontal_direction := -1.0 if wheel.name.ends_with("Left") else 1.0
	var escape_direction := Vector2(horizontal_direction * 0.55, -1.0).normalized()
	# Cancel the existing velocity first so the escape impulse isn't fighting
	# whatever rebound direction the ball currently has.
	linear_velocity = Vector2.ZERO
	apply_central_impulse(escape_direction * wheel_escape_impulse)
