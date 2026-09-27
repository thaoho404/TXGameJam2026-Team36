extends RigidBody2D

@export_range(100.0, 10000.0, 100.0) var max_linear_speed: float = 3200.0


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Fast bumper and target rebounds can push the ball through the thin edge
	# of the table in a single physics step.
	if state.linear_velocity.length_squared() > max_linear_speed * max_linear_speed:
		state.linear_velocity = state.linear_velocity.limit_length(max_linear_speed)


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 3
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name.begins_with("Bumper"):
		print("Hit ", body.name)
		var sprite = $Sprite2D
		if sprite:
			sprite.modulate = Color(2, 2, 2) 
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
