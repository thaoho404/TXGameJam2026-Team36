class_name PinballController
extends Node2D

signal ball_launched()
signal bumper_hit(element: BevoData.ElementType, points: int)
signal ball_drained()

enum BoardState { STOPPED, PREPARING, READY, IN_PLAY }

@export var bumper_points: int = 10
@export var spawn_position: Vector2 = Vector2(535, 520)
@export_range(0.0, 2.0, 0.05) var bumper_score_cooldown_seconds: float = 0.35
@export_range(0.0, 3.0, 0.05) var wheel_score_cooldown_seconds: float = 1.0
@export_range(0, 1000, 1) var element_strip_points: int = 25

@onready var left_flipper: AnimatableBody2D = $Flippers/LeftFlipper
@onready var right_flipper: AnimatableBody2D = $Flippers/RightFlipper
@onready var plunger: PinballPlunger = $Plunger
@onready var ball: RigidBody2D = $BevoBall
@onready var ball_sprite: Sprite2D = $BevoBall/Sprite2D
@onready var ball_trap = $BallTrap
@onready var element_strips = $ElementStrips

var board_state: BoardState = BoardState.STOPPED
var _request_revision: int = 0
var _initial_sprite_scale: Vector2
var _initial_collision_mask: int
var _last_bumper_score_ms: Dictionary[int, int] = {}

const LEFT_REST_ANGLE := deg_to_rad(18.0)
const LEFT_ACTIVE_ANGLE := deg_to_rad(-28.0)
const RIGHT_REST_ANGLE := deg_to_rad(-18.0)
const RIGHT_ACTIVE_ANGLE := deg_to_rad(28.0)


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
		left_flipper.rotation = move_toward(left_flipper.rotation, LEFT_ACTIVE_ANGLE, 35 * delta)
	else:
		left_flipper.rotation = move_toward(left_flipper.rotation, LEFT_REST_ANGLE, 20 * delta)

	if controls_enabled and Input.is_action_pressed("ui_right"):
		right_flipper.rotation = move_toward(right_flipper.rotation, RIGHT_ACTIVE_ANGLE, 35 * delta)
	else:
		right_flipper.rotation = move_toward(right_flipper.rotation, RIGHT_REST_ANGLE, 20 * delta)


func prepare_next_ball() -> void:
	_request_revision += 1
	board_state = BoardState.PREPARING
	plunger.disarm()
	_apply_preparation.call_deferred(_request_revision)


func stop_board() -> void:
	_request_revision += 1
	board_state = BoardState.STOPPED
	plunger.disarm()
	ball_trap.reset_trap()
	element_strips.reset_strips()
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
	_last_bumper_score_ms.clear()
	ball_trap.reset_trap()
	element_strips.reset_strips()
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
	var now_ms := Time.get_ticks_msec()
	var bumper_id := body.get_instance_id()
	var last_score_ms: int = _last_bumper_score_ms.get(bumper_id, -1000000)
	var cooldown_seconds := (
		wheel_score_cooldown_seconds
		if body.name.begins_with("BumperWheel")
		else bumper_score_cooldown_seconds
	)
	if now_ms - last_score_ms < int(cooldown_seconds * 1000.0):
		return
	_last_bumper_score_ms[bumper_id] = now_ms
	bumper_hit.emit(BevoData.ElementType.NORMAL, maxi(0, bumper_points))


func _on_drain_zone_body_entered(body: Node2D) -> void:
	if body != ball or board_state != BoardState.IN_PLAY:
		return
	# Close scoring and input before notifying combat; freeze outside the callback.
	stop_board()
	ball_drained.emit()


func _on_ball_trap_score_tick(points: int) -> void:
	if board_state == BoardState.IN_PLAY:
		bumper_hit.emit(BevoData.ElementType.NORMAL, maxi(0, points))


func _on_element_strips_triggered(element: BevoData.ElementType) -> void:
	if board_state == BoardState.IN_PLAY:
		bumper_hit.emit(element, maxi(0, element_strip_points))
