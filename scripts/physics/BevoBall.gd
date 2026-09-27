extends RigidBody2D

@export_range(100.0, 10000.0, 100.0) var max_linear_speed: float = 3200.0
var _roof_points := PackedVector2Array()
var _ball_radius: float = 25.0


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
		var sprite = $Sprite2D
		if sprite:
			sprite.modulate = Color(2, 2, 2) 
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
