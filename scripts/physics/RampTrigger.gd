extends Area2D

@export_enum("Entrance", "Exit") var trigger_type: String = "Entrance"

func _on_body_entered(body: Node2D) -> void:
	if "BevoBall" in body.name:
		if trigger_type == "Entrance":
			body.set_collision_mask_value(1, false) # Ignore Ground
			body.set_collision_mask_value(2, true)  # Hit Ramp Walls
			
			var tween = create_tween()
			tween.tween_property(body.get_node("Sprite2D"), "scale", Vector2(0.2, 0.2), 0.2)
			
		elif trigger_type == "Exit":
			body.set_collision_mask_value(1, true)  # Hit Ground
			body.set_collision_mask_value(2, false) # Ignore Ramp Walls
			
			var tween = create_tween()
			tween.tween_property(body.get_node("Sprite2D"), "scale", Vector2(0.15, 0.15), 0.2)