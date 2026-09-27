class_name BallTrap
extends Area2D

signal score_tick(points: int)
signal ball_released(speed: float)

@export_range(0.1, 10.0, 0.1) var hold_seconds: float = 2.0
@export_range(0.1, 2.0, 0.1) var score_interval: float = 0.4
@export_range(0, 1000, 1) var points_per_tick: int = 5
@export_range(100.0, 3000.0, 50.0) var eject_speed: float = 1400.0
@export var eject_direction: Vector2 = Vector2(1.0, 0.3)

var _trapped_ball: RigidBody2D
var _released_ball: RigidBody2D
var _capture_revision: int = 0
var _captured_this_ball: bool = false


func _on_body_entered(body: Node2D) -> void:
	if _captured_this_ball or _trapped_ball or _released_ball or not body is RigidBody2D or body.name != "BevoBall" or body.freeze:
		return
	_capture_ball.call_deferred(body)


func _on_body_exited(body: Node2D) -> void:
	if body != _released_ball:
		return
	var revision := _capture_revision
	await get_tree().create_timer(0.75).timeout
	if revision == _capture_revision and body == _released_ball:
		_released_ball = null


func _capture_ball(body: RigidBody2D) -> void:
	if _trapped_ball or not is_instance_valid(body):
		return
	_capture_revision += 1
	var revision := _capture_revision
	_trapped_ball = body
	_captured_this_ball = true
	body.freeze = true
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	body.global_position = global_position
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)

	var elapsed := 0.0
	while elapsed < hold_seconds:
		await get_tree().create_timer(minf(score_interval, hold_seconds - elapsed)).timeout
		if revision != _capture_revision or not is_instance_valid(_trapped_ball):
			return
		elapsed += score_interval
		score_tick.emit(points_per_tick)

	_release_ball(revision)


func _release_ball(revision: int) -> void:
	if revision != _capture_revision or not is_instance_valid(_trapped_ball):
		return
	var body := _trapped_ball
	_trapped_ball = null
	_released_ball = body
	body.global_position = $EjectPoint.global_position
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)
	body.freeze = false
	body.linear_velocity = eject_direction.normalized() * eject_speed
	ball_released.emit(body.linear_velocity.length())


func reset_trap() -> void:
	_capture_revision += 1
	if is_instance_valid(_trapped_ball):
		_trapped_ball.freeze = false
	_trapped_ball = null
	_released_ball = null
	_captured_this_ball = false
