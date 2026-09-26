extends StaticBody2D

@export var kick_force: float = 800.0

func _on_kicker_trigger_body_entered(body: Node2D) -> void:
	if "BevoBall" in body.name:
		# Calculates the correct bounce angle based on how you rotated the slingshot in the editor
		var kick_direction = Vector2.LEFT.rotated(global_rotation)
		body.apply_central_impulse(kick_direction * kick_force)
		
		# Visual juice: quickly pop the scale
		var tween = create_tween()
		$Visual.scale = Vector2(1.2, 1.2)
		tween.tween_property($Visual, "scale", Vector2(1.0, 1.0), 0.15)
