extends StaticBody2D

signal kicked()

@export var kick_direction: Vector2 = Vector2.RIGHT
@export_range(0.0, 2000.0, 50.0) var kick_strength: float = 850.0
@export_range(0.0, 1.0, 0.01) var cooldown_seconds: float = 0.12

var _last_kick_ms: int = -1000000


func _on_trigger_body_entered(body: Node2D) -> void:
	if not body is RigidBody2D or body.name != "BevoBall" or body.freeze:
		return
	var direction := kick_direction.normalized()
	# A physical wall bounce may reverse the ball before the Area2D callback.
	# Still add a kick unless it is already moving strongly toward the table.
	if direction == Vector2.ZERO or body.linear_velocity.dot(direction) >= kick_strength:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_kick_ms < int(cooldown_seconds * 1000.0):
		return
	_last_kick_ms = now_ms
	body.apply_central_impulse(direction * kick_strength)
	kicked.emit()
