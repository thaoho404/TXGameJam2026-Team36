class_name RampConveyor
extends Area2D

@export_range(0.0, 3000.0, 25.0) var minimum_forward_speed: float = 650.0
@export_range(0.0, 20.0, 0.5) var lateral_damping: float = 10.0


func _physics_process(delta: float) -> void:
	var forward := global_transform.x.normalized()
	var lateral := global_transform.y.normalized()
	for body in get_overlapping_bodies():
		if not body is RigidBody2D or body.name != "BevoBall" or not body.get_collision_mask_value(2):
			continue
		var rigid_body := body as RigidBody2D
		var forward_speed: float = rigid_body.linear_velocity.dot(forward)
		if forward_speed < minimum_forward_speed:
			rigid_body.linear_velocity += forward * (minimum_forward_speed - forward_speed)
		var lateral_speed: float = rigid_body.linear_velocity.dot(lateral)
		rigid_body.linear_velocity -= lateral * lateral_speed * minf(1.0, lateral_damping * delta)


func _on_body_exited(body: Node2D) -> void:
	if not body is RigidBody2D or body.name != "BevoBall" or not body.get_collision_mask_value(2):
		return
	# Failsafe for a ball that leaves the visual ramp before touching its exit sensor.
	body.z_index = 0
	body.set_collision_mask_value(2, false)
	body.set_collision_mask_value(1, true)
