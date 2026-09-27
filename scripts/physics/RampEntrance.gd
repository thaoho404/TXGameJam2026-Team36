extends Node2D

@export var entrance_boost: float = 350.0
@export var ramp_direction: Vector2 = Vector2.UP
@export var minimum_entry_speed: float = 50.0
@export var entry_window_seconds: float = 1.0
@export var entry_center_half_width: float = 14.0
@export var center_on_local_y: bool = false

const ENTRY_ARMED_META := &"ramp_entry_armed_at"

@onready var front_sensor: Area2D = $FrontSensor
@onready var commit_sensor: Area2D = $CommitSensor

func _on_front_sensor_body_entered(body: Node2D) -> void:
	if not _is_playfield_ball(body):
		return
	if absf(_lateral_offset(front_sensor, body)) > entry_center_half_width:
		return

	var direction := ramp_direction.normalized().rotated(global_rotation)
	if body.linear_velocity.dot(direction) < minimum_entry_speed:
		return

	body.set_meta(ENTRY_ARMED_META, Time.get_ticks_msec())

func _on_commit_sensor_body_entered(body: Node2D) -> void:
	if not _is_playfield_ball(body) or not body.has_meta(ENTRY_ARMED_META):
		return
	if absf(_lateral_offset(commit_sensor, body)) > entry_center_half_width:
		body.remove_meta(ENTRY_ARMED_META)
		return

	var armed_at: int = body.get_meta(ENTRY_ARMED_META)
	body.remove_meta(ENTRY_ARMED_META)

	var elapsed_seconds := (Time.get_ticks_msec() - armed_at) / 1000.0
	var direction := ramp_direction.normalized().rotated(global_rotation)
	if elapsed_seconds > entry_window_seconds:
		return
	if body.linear_velocity.dot(direction) < minimum_entry_speed:
		return

	# Snap the ball onto the rail centerline before it switches onto the ramp
	# collision layer. The entry check above only has to be "close enough";
	# without this, a ball that was a few pixels off-center at commit would
	# switch onto the ramp already clipping a rail and could catch on it
	# instead of riding through.
	var local_pos := to_local(body.global_position)
	if center_on_local_y:
		local_pos.y = 0.0
	else:
		local_pos.x = 0.0
	body.global_position = to_global(local_pos)
	PhysicsServer2D.body_set_state(body.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, body.global_transform)

	body.z_index = 10
	body.set_collision_mask_value(1, false)
	body.set_collision_mask_value(2, true)
	body.continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	body.apply_central_impulse(direction * entrance_boost)

func _is_playfield_ball(body: Node2D) -> bool:
	return (
		body is RigidBody2D
		and body.name == "BevoBall"
		and body.get_collision_mask_value(1)
		and not body.get_collision_mask_value(2)
	)


func _lateral_offset(sensor: Area2D, body: Node2D) -> float:
	var local_position := sensor.to_local(body.global_position)
	return local_position.y if center_on_local_y else local_position.x
