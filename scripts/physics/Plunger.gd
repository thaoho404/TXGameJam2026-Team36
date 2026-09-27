extends Node2D

@export var max_power: float = 2000.0
@export var charge_rate: float = 1500.0
@export var pull_distance: float = 80.0

var current_power: float = 0.0
var is_charging: bool = false
var ball_in_chamber: RigidBody2D = null

# Replace "VisualBlock" with the exact name of your artwork node
@onready var visual_stick = $VisualBlock 
@onready var start_y: float = visual_stick.position.y

func _ready() -> void:
	# Forces the plunger to start at its highest position when the game boots
	visual_stick.position.y = start_y

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept") and ball_in_chamber:
		is_charging = true
		current_power = 0.0

	if Input.is_action_pressed("ui_accept") and is_charging:
		current_power = move_toward(current_power, max_power, charge_rate * delta)
		
		# Pulls ONLY the picture down, leaving the invisible floor holding the ball
		var power_ratio = current_power / max_power
		visual_stick.position.y = start_y + (power_ratio * pull_distance)

	if Input.is_action_just_released("ui_accept") and is_charging:
		is_charging = false
		
		if ball_in_chamber:
			# The script fires the ball off the stationary shelf
			ball_in_chamber.apply_central_impulse(Vector2.UP * current_power)
			
		current_power = 0.0
		
		# The picture snaps back up harmlessly because it has no collision shape
		visual_stick.position.y = start_y

func _on_chamber_body_entered(body: Node2D) -> void:
	if body.name == "Player_Bevo": 
		ball_in_chamber = body

func _on_chamber_body_exited(body: Node2D) -> void:
	if body == ball_in_chamber:
		ball_in_chamber = null
