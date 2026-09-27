class_name PinballController
extends Node2D

signal ball_launched()
signal bumper_hit(element: BevoData.ElementType, points: int)
signal ball_drained()

enum BoardState { STOPPED, PREPARING, READY, IN_PLAY }

@export var bumper_points: int = 10
@export var spawn_position: Vector2 = Vector2(535, 520)

@onready var left_flipper: AnimatableBody2D = $Flippers/LeftFlipper
@onready var right_flipper: AnimatableBody2D = $Flippers/RightFlipper
@onready var plunger: PinballPlunger = $Plunger
@onready var ball: RigidBody2D = $BevoBall
@onready var ball_sprite: Sprite2D = $BevoBall/Sprite2D

var board_state: BoardState = BoardState.STOPPED
var _request_revision: int = 0
var _initial_sprite_scale: Vector2
var _initial_collision_mask: int


func _ready() -> void:
	_initial_sprite_scale = ball_sprite.scale
	_initial_collision_mask = ball.collision_mask
	plunger.ball_launched.connect(_on_plunger_ball_launched)
	ball.body_entered.connect(_on_ball_body_entered)
	ball.freeze = true
	stop_board()


func _physics_process(delta: float) -> void:
	var controls_enabled := board_state == BoardState.READY or board_state == BoardState.IN_PLAY
	if controls_enabled and Input.is_action_pressed("ui_left"):
		left_flipper.rotation = move_toward(left_flipper.rotation, deg_to_rad(-45), 35 * delta)
	else:
		left_flipper.rotation = move_toward(left_flipper.rotation, deg_to_rad(25), 20 * delta)

	if controls_enabled and Input.is_action_pressed("ui_right"):
		right_flipper.rotation = move_toward(right_flipper.rotation, deg_to_rad(45), 35 * delta)
	else:
		right_flipper.rotation = move_toward(right_flipper.rotation, deg_to_rad(-25), 20 * delta)


func prepare_next_ball() -> void:
	_request_revision += 1
	board_state = BoardState.PREPARING
	plunger.disarm()
	_apply_preparation.call_deferred(_request_revision)


func stop_board() -> void:
	_request_revision += 1
	board_state = BoardState.STOPPED
	plunger.disarm()
	_freeze_ball.call_deferred(_request_revision)


func _apply_preparation(revision: int) -> void:
	# A newer stop/serve request takes precedence over queued physics changes.
	if revision != _request_revision or board_state != BoardState.PREPARING:
		return
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.position = spawn_position
	ball.rotation = 0.0
	# Keep the physics body in the same place as its node before it can launch.
	# A frozen RigidBody2D may otherwise retain its previous physics transform.
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, ball.global_transform)
	ball.z_index = 0
	ball.collision_mask = _initial_collision_mask
	ball.set_collision_mask_value(1, true)
	ball.set_collision_mask_value(2, false)
	ball_sprite.scale = _initial_sprite_scale
	if ball.has_meta(&"ramp_entry_armed_at"):
		ball.remove_meta(&"ramp_entry_armed_at")
	board_state = BoardState.READY
	plunger.arm_ball(ball)


func _freeze_ball(revision: int) -> void:
	if revision != _request_revision or board_state != BoardState.STOPPED:
		return
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0


func _on_plunger_ball_launched() -> void:
	if board_state != BoardState.READY:
		return
	board_state = BoardState.IN_PLAY
	ball_launched.emit()


func _on_ball_body_entered(body: Node) -> void:
	if board_state != BoardState.IN_PLAY or body.get_parent() != $Bumpers:
		return
	bumper_hit.emit(BevoData.ElementType.NORMAL, maxi(0, bumper_points))


func _on_drain_zone_body_entered(body: Node2D) -> void:
	if body != ball or board_state != BoardState.IN_PLAY:
		return
	# Close scoring and input before notifying combat; freeze outside the callback.
	stop_board()
	ball_drained.emit()
