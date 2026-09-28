extends RigidBody2D

@export_range(100.0, 10000.0, 100.0) var max_linear_speed: float = 3200.0
@export_range(0.0, 1000.0, 25.0) var wheel_escape_impulse: float = 650.0
@export_range(2, 6, 1) var wheel_escape_contacts: int = 3
@export_range(0.1, 2.0, 0.05) var wheel_escape_window_seconds: float = 0.65
@export_range(0.0, 200.0, 5.0) var stall_speed: float = 55.0
@export_range(0.1, 5.0, 0.05) var stall_seconds: float = 0.4
@export_range(0.0, 1000.0, 25.0) var stall_escape_speed: float = 480.0

var _last_wheel_escape_ms: int = -1000000
var _last_wheel_hit_ms: int = -1000000
var _last_wheel_name: StringName = &""
var _wheel_pocket_hits: int = 0
var _stall_elapsed: float = 0.0
var _roof_points := PackedVector2Array()
var _ball_radius: float = 25.0


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Fast bumper and target rebounds can push the ball through the thin edge
	# of the table in a single physics step.
	if state.linear_velocity.length_squared() > max_linear_speed * max_linear_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_linear_speed)
	# CCD can still miss a sloped roof after a very fast rebound.
	_keep_inside_roof(state)

	# Recover from shallow collider pockets without interfering with the plunger lane.
	if global_position.x < 490.0 and state.linear_velocity.length() < stall_speed:
		_stall_elapsed += state.step
		if _stall_elapsed >= stall_seconds:
			var horizontal_sign := 1.0 if global_position.x < 287.0 else -1.0
			state.linear_velocity = Vector2(horizontal_sign * 0.45, -1.0).normalized() * stall_escape_speed
			_stall_elapsed = 0.0
	else:
		_stall_elapsed = 0.0


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
			_maybe_escape_lower_wheels(body)
		var sprite := body.get_node_or_null("Sprite2D") as Sprite2D
		if sprite:
			sprite.modulate = Color(2, 2, 2) 
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)


func _maybe_escape_lower_wheels(wheel: Node2D) -> void:
	var bumpers := wheel.get_parent()
	var left_wheel := bumpers.get_node_or_null("BumperWheelLeft") as Node2D
	var right_wheel := bumpers.get_node_or_null("BumperWheelRight") as Node2D
	var collision := wheel.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if left_wheel == null or right_wheel == null or collision == null or not collision.shape is CircleShape2D:
		return
	var contact_radius := (collision.shape as CircleShape2D).radius + _ball_radius
	# Only the narrow gap between the inner wheel faces can trap the ball.
	var inside_pocket := (
		global_position.x >= left_wheel.global_position.x + contact_radius - 12.0
		and global_position.x <= right_wheel.global_position.x - contact_radius + 12.0
		and absf(global_position.y - wheel.global_position.y) <= contact_radius
	)
	if not inside_pocket:
		_wheel_pocket_hits = 0
		_last_wheel_name = &""
		return

	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_wheel_hit_ms > roundi(wheel_escape_window_seconds * 1000.0) or wheel.name == _last_wheel_name:
		_wheel_pocket_hits = 1
	else:
		_wheel_pocket_hits += 1
	_last_wheel_hit_ms = now_ms
	_last_wheel_name = wheel.name
	if _wheel_pocket_hits < wheel_escape_contacts:
		return
	_wheel_pocket_hits = 0
	if now_ms - _last_wheel_escape_ms < 180:
		return
	_last_wheel_escape_ms = now_ms

	# A genuine ping-pong trap gets one straight-up escape, with no ramp bias.
	linear_velocity = Vector2.ZERO
	apply_central_impulse(Vector2.UP * wheel_escape_impulse)
