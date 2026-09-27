extends StaticBody2D

signal valid_hit()

var is_dropped: bool = false

func _on_hitbox_body_entered(body: Node2D) -> void:
	# Ignore if already down or if a random particle hits it instead of Bevo
	print("Hit by: ", body.name)
	if is_dropped or body.name != "BevoBall": 
		return
		
	is_dropped = true
	valid_hit.emit()
	
	# Hide the 1930s lineman art
	$VisualPlaceholder.hide() 
	
	# Turn off the solid physical wall (set_deferred prevents physics engine crashes)
	$SolidWall.set_deferred("disabled", true)
	
	# Wait 5 seconds, then pop back up
	await get_tree().create_timer(5.0).timeout
	# Restoring the wall around the ball can eject it at high speed.
	while _ball_overlaps_hitbox():
		await get_tree().physics_frame
	
	is_dropped = false
	$VisualPlaceholder.show()
	$SolidWall.set_deferred("disabled", false)


func _ball_overlaps_hitbox() -> bool:
	for body in $Hitbox.get_overlapping_bodies():
		if body.name == "BevoBall":
			return true
	return false
