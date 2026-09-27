class_name PinballController
extends Node2D

signal ball_launched()
signal ball_rearmed()
signal bumper_hit(element: BevoData.ElementType, points: int)
signal ball_drained()

enum BoardState { STOPPED, PREPARING, READY, IN_PLAY }

@export var bumper_points: int = 10
@export var spawn_position: Vector2 = Vector2(535, 520)
@export_range(0.0, 2.0, 0.05) var bumper_score_cooldown_seconds: float = 0.35
@export_range(0.0, 3.0, 0.05) var wheel_score_cooldown_seconds: float = 1.0
@export_range(0, 1000, 1) var element_strip_points: int = 25
@export_range(0.25, 10.0, 0.25) var launch_lane_stall_seconds: float = 2.0
@export_range(1.0, 20.0, 0.5) var launch_lane_max_seconds: float = 6.0
@export var launch_lane_rescue_position: Vector2 = Vector2(250, 245)

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
var _initial_ball_texture: Texture2D
var _bumper_types: Dictionary = {}
var _target_hits: int = 0
var _last_speed_multiplier: float = 1.0
var _rng := RandomNumberGenerator.new()
var _launch_lane_anchor: Vector2 = Vector2.ZERO
var _launch_lane_time: float = 0.0
var _still_time: float = 0.0
var _rescue_pending: bool = false

const LEFT_REST_ANGLE := deg_to_rad(18.0)
const LEFT_ACTIVE_ANGLE := deg_to_rad(-28.0)
const RIGHT_REST_ANGLE := deg_to_rad(-18.0)
const RIGHT_ACTIVE_ANGLE := deg_to_rad(28.0)
const BUMPER_ELEMENTS := [BevoData.ElementType.NORMAL, BevoData.ElementType.WATER, BevoData.ElementType.GRASS, BevoData.ElementType.FIRE, BevoData.ElementType.EARTH, BevoData.ElementType.ICE, BevoData.ElementType.WIND, BevoData.ElementType.ELECTRIC, BevoData.ElementType.STEEL, BevoData.ElementType.FAIRY, BevoData.ElementType.DARK]
const TARGET_ELEMENTS := [BevoData.ElementType.PSYCHIC, BevoData.ElementType.GHOST, BevoData.ElementType.NORMAL, BevoData.ElementType.WATER, BevoData.ElementType.GRASS, BevoData.ElementType.FIRE, BevoData.ElementType.EARTH, BevoData.ElementType.ICE, BevoData.ElementType.WIND, BevoData.ElementType.ELECTRIC, BevoData.ElementType.STEEL, BevoData.ElementType.FAIRY, BevoData.ElementType.DARK]


func _ready() -> void:
	_initial_sprite_scale = ball_sprite.scale
	_initial_collision_mask = ball.collision_mask
	_initial_ball_texture = ball_sprite.texture
	_rng.randomize()
	for target in get_children():
		if target.name.begins_with("DropTarget"):
			target.valid_hit.connect(_on_target_hit)
	randomize_bumpers()
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
	_watch_launch_lane(delta)


func _in_launch_lane() -> bool:
	if board_state != BoardState.IN_PLAY:
		return false
	var point := ball.position
	if point.x < 505.0 or point.x > 574.0 or point.y < 160.0 or point.y > 648.0:
		return false
	# A returned ball already at the plunger is ready for a normal relaunch.
	return not (plunger._armed_ball == ball and point.y >= 480.0)


func _watch_launch_lane(delta: float) -> void:
	if not _in_launch_lane():
		_reset_launch_lane_watch()
		return
	if _launch_lane_time == 0.0:
		_launch_lane_anchor = ball.position
	_launch_lane_time += delta
	if ball.position.distance_to(_launch_lane_anchor) >= 30.0:
		_launch_lane_anchor = ball.position
		_still_time = 0.0
	else:
		_still_time += delta
	if not _rescue_pending and (_still_time >= launch_lane_stall_seconds or _launch_lane_time >= launch_lane_max_seconds):
		_rescue_pending = true
		_rescue_stuck_ball.call_deferred(_request_revision)


func _reset_launch_lane_watch() -> void:
	_launch_lane_time = 0.0
	_still_time = 0.0
	_rescue_pending = false


func _rescue_stuck_ball(revision: int) -> void:
	if revision != _request_revision or not _in_launch_lane():
		_reset_launch_lane_watch()
		return
	var return_to_plunger := ball.position.y >= 450.0
	ball.freeze = true
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	ball.position = spawn_position if return_to_plunger else launch_lane_rescue_position
	PhysicsServer2D.body_set_state(ball.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, ball.global_transform)
	ball.z_index = 0
	ball.set_collision_mask_value(1, true)
	ball.set_collision_mask_value(2, false)
	if ball.has_meta(&"ramp_entry_armed_at"):
		ball.remove_meta(&"ramp_entry_armed_at")
	if return_to_plunger:
		plunger.arm_ball(ball)
	else:
		plunger.disarm()
	ball.freeze = false
	ball.sleeping = false
	ball.linear_velocity = Vector2.ZERO if return_to_plunger else Vector2(180, 120)
	_reset_launch_lane_watch()
	if return_to_plunger:
		ball_rearmed.emit()


func prepare_next_ball() -> void:
	_request_revision += 1
	_reset_launch_lane_watch()
	board_state = BoardState.PREPARING
	plunger.disarm()
	_apply_preparation.call_deferred(_request_revision)


func set_ball_type(ball_type: BallType) -> void:
	ball_sprite.texture = ball_type.ball_texture if ball_type != null and ball_type.ball_texture != null else _initial_ball_texture
	plunger.launch_multiplier = ball_type.speed_multiplier if ball_type != null else 1.0


func randomize_bumpers() -> void:
	_bumper_types.clear()
	_target_hits = 0
	for bumper in $Bumpers.get_children():
		var element: BevoData.ElementType = BUMPER_ELEMENTS[_rng.randi_range(0, BUMPER_ELEMENTS.size() - 1)]
		_bumper_types[bumper] = element
		var label := bumper.get_node_or_null("ElementLabel") as Label
		if label == null:
			label = Label.new()
			label.name = "ElementLabel"
			label.position = Vector2(-30, -36)
			label.size = Vector2(60, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_size_override("font_size", 13)
			label.add_theme_color_override("font_shadow_color", Color.BLACK)
			label.add_theme_constant_override("shadow_offset_x", 1)
			label.add_theme_constant_override("shadow_offset_y", 1)
			bumper.add_child(label)
		label.text = BevoData.ElementType.keys()[element].capitalize()


func apply_speed_multiplier(multiplier: float) -> void:
	if board_state == BoardState.IN_PLAY:
		ball.linear_velocity *= multiplier / _last_speed_multiplier
	_last_speed_multiplier = multiplier


func stop_board() -> void:
	_request_revision += 1
	_reset_launch_lane_watch()
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
	_last_speed_multiplier = 1.0
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
	bumper_hit.emit(_bumper_types.get(body, BevoData.ElementType.NORMAL), maxi(0, bumper_points))


func _on_target_hit() -> void:
	if board_state != BoardState.IN_PLAY:
		return
	_target_hits += 1
	if _target_hits >= 5:
		_target_hits = 0
		bumper_hit.emit(TARGET_ELEMENTS[_rng.randi_range(0, TARGET_ELEMENTS.size() - 1)], maxi(0, bumper_points))


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
