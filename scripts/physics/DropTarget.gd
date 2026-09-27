extends StaticBody2D

var is_dropped: bool = false

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Ignore if already down or if a random particle hits it instead of Bevo
	print("Hit by: ", body.name)
	if is_dropped or body.name != "BevoBall": 
		return
		
	is_dropped = true
	
	# Hide the 1930s lineman art
	$VisualPlaceholder.hide() 
	
	# Turn off the solid physical wall (set_deferred prevents physics engine crashes)
	$SolidWall.set_deferred("disabled", true)
	
	# Wait 5 seconds, then pop back up
	await get_tree().create_timer(5.0).timeout
	
	is_dropped = false
	$VisualPlaceholder.show()
	$SolidWall.set_deferred("disabled", false)
