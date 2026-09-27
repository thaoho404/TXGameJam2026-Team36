extends Area2D

@export var kick_power: float = 1200.0
@export var bounce_direction: Vector2 = Vector2(-1, -1)
@export var cooldown_time: float = 0.15

var is_firing: bool = false
var ball_inside: RigidBody2D = null

func _ready() -> void:
	bounce_direction = bounce_direction.normalized()

# This checks every single physics frame instead of just once when crossing the line
func _physics_process(_delta: float) -> void:
	if ball_inside and not is_firing:
		fire_slingshot()

# We only use signals to track if Bevo is currently standing in the zone
func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player_Bevo":
		ball_inside = body

func _on_body_exited(body: Node2D) -> void:
	if body == ball_inside:
		ball_inside = null

func fire_slingshot() -> void:
	is_firing = true
	
	# Stop existing momentum and fire
	ball_inside.linear_velocity = Vector2.ZERO 
	ball_inside.apply_central_impulse(bounce_direction * kick_power)
	
	# Wait for cooldown
	await get_tree().create_timer(cooldown_time).timeout
	
	# Unlock the slingshot
	is_firing = false
