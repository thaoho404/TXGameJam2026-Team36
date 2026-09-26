extends Node2D

@onready var left_flipper = $Flippers/LeftFlipper
@onready var right_flipper = $Flippers/RightFlipper
@onready var plunger: AnimatableBody2D = $Plunger
@onready var ball: RigidBody2D = $BevoBall

var plunger_power: float = 0.0
var max_plunger_pull: float = 50.0

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		left_flipper.rotation = move_toward(left_flipper.rotation, deg_to_rad(-45), 35 * delta)
	else:
		left_flipper.rotation = move_toward(left_flipper.rotation, deg_to_rad(25), 20 * delta)
		
	if Input.is_action_pressed("ui_right"):
		right_flipper.rotation = move_toward(right_flipper.rotation, deg_to_rad(45), 35 * delta)
	else:
		right_flipper.rotation = move_toward(right_flipper.rotation, deg_to_rad(-25), 20 * delta)

	if Input.is_action_pressed("ui_accept"):
		plunger_power = move_toward(plunger_power, max_plunger_pull, 100 * delta)
		plunger.position.y = 580 + plunger_power
	elif Input.is_action_just_released("ui_accept"):
		if plunger_power > 10.0 and ball.position.y > 500 and ball.position.x > 490:
			ball.apply_central_impulse(Vector2(0, -plunger_power * 45))
		plunger_power = 0.0
		plunger.position.y = 580
		
		# Add this function to the bottom of PinballController.gd
func _on_drain_zone_body_entered(body: Node2D) -> void:
	if body.name == "BevoBall":
		print("Ball Drained! Resetting to plunger...")
		
		# Stop all momentum
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		
		# Teleport back to the plunger lane
		body.position = Vector2(535, 520)
