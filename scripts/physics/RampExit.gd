extends Area2D

const ENTRY_ARMED_META := &"ramp_entry_armed_at"

func _on_body_entered(body: Node2D) -> void:
	if body.name == "BevoBall":
		# SECURITY CHECK: Only trigger if Bevo is currently on the elevated ramp layer
		if body.get_collision_mask_value(2) == true:
			
			# 1. Drop the visual artwork back down
			body.z_index = 0 
			
			# 2. Swap physics layers back to normal
			body.set_collision_mask_value(2, false) # Ignore ramp walls
			body.set_collision_mask_value(1, true)  # Hit main playfield
			if body.has_meta(ENTRY_ARMED_META):
				body.remove_meta(ENTRY_ARMED_META)
