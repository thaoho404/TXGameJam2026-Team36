class_name IceRamp
extends Area2D

@export_range(0.1, 1.0, 0.05) var entry_speed_multiplier: float = 0.68
@export_range(0.0, 2000.0, 25.0) var minimum_exit_speed: float = 350.0
@export_range(0.0, 1.0, 0.05) var guide_amount: float = 0.6
@export var local_travel_direction: Vector2 = Vector2.LEFT


func _on_body_entered(body: Node2D) -> void:
	if not body is RigidBody2D or body.name != "BevoBall" or body.freeze:
		return
	var slowed_speed: float = maxf(body.linear_velocity.length() * entry_speed_multiplier, minimum_exit_speed)
	var current_direction: Vector2 = body.linear_velocity.normalized()
	var ramp_direction: Vector2 = local_travel_direction.normalized().rotated(global_rotation)
	if current_direction == Vector2.ZERO:
		current_direction = ramp_direction
	body.linear_velocity = current_direction.lerp(ramp_direction, guide_amount).normalized() * slowed_speed
