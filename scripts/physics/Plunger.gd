class_name PinballPlunger
extends StaticBody2D

signal ball_launched()

@export var max_power: float = 2000.0
@export var minimum_power: float = 450.0
@export var charge_rate: float = 1500.0
@export var pull_distance: float = 80.0

var current_power: float = 0.0
var is_charging: bool = false
var ball_in_chamber: RigidBody2D = null
var _served_ball: RigidBody2D = null
var _armed_ball: RigidBody2D = null
var _wait_for_input_release: bool = false
var _launch_physics_frame: int = -1

@onready var visual_stick: ColorRect = $VisualBlock
@onready var start_y: float = visual_stick.position.y


func _ready() -> void:
	_reset_charge()


func arm_ball(next_ball: RigidBody2D) -> void:
	_reset_charge()
	_served_ball = next_ball
	_armed_ball = next_ball
	# A frozen ball does not need to retrigger the chamber sensor to be served.
	ball_in_chamber = next_ball
	_wait_for_input_release = Input.is_action_pressed("ui_accept")


func disarm() -> void:
	_served_ball = null
	_armed_ball = null
	ball_in_chamber = null
	_wait_for_input_release = false
	_reset_charge()


func _physics_process(delta: float) -> void:
	# A weak shot may return to the launch lane; that is still the same turn.
	if (
		not is_instance_valid(_armed_ball)
		and is_instance_valid(_served_ball)
		and ball_in_chamber == _served_ball
		and _served_ball.linear_velocity.y >= 0.0
		and Engine.get_physics_frames() > _launch_physics_frame
	):
		arm_ball(_served_ball)
	if not is_instance_valid(_armed_ball):
		return
	# Releasing the key that confirmed a menu must not launch the served ball.
	if _wait_for_input_release:
		if not Input.is_action_pressed("ui_accept"):
			_wait_for_input_release = false
		return

	if Input.is_action_just_pressed("ui_accept"):
		is_charging = true
		current_power = 0.0

	if Input.is_action_pressed("ui_accept") and is_charging:
		current_power = move_toward(current_power, maxf(0.0, max_power), charge_rate * delta)
		var power_ratio := current_power / maxf(1.0, max_power)
		# Only the artwork moves; the shelf stays in place.
		visual_stick.position.y = start_y + power_ratio * pull_distance

	if Input.is_action_just_released("ui_accept") and is_charging:
		request_launch(current_power)
		_reset_charge()


func request_launch(power: float) -> bool:
	if not is_instance_valid(_armed_ball) or _wait_for_input_release:
		return false
	var launch_power := clampf(power, 0.0, maxf(0.0, max_power))
	if launch_power < maxf(1.0, minimum_power):
		return false

	var launched_ball := _armed_ball
	_armed_ball = null
	_wait_for_input_release = false
	_launch_physics_frame = Engine.get_physics_frames()
	_reset_charge()
	launched_ball.freeze = false
	launched_ball.sleeping = false
	launched_ball.apply_central_impulse(Vector2.UP * launch_power)
	ball_launched.emit()
	return true


func _reset_charge() -> void:
	is_charging = false
	current_power = 0.0
	visual_stick.position.y = start_y


func _on_chamber_body_entered(body: Node2D) -> void:
	if body == _served_ball:
		ball_in_chamber = _served_ball


func _on_chamber_body_exited(body: Node2D) -> void:
	if body == ball_in_chamber:
		ball_in_chamber = null
