class_name TurnManager
extends Node

enum BattleState { PREP, BALL_IN_PLAY, DAMAGE_CALCULATION, ENEMY_PHASE, CHECK_STATUS, GAME_OVER, VICTORY }

signal state_changed(new_state: BattleState)
signal turn_combo_updated(current_hits: int, preview_damage: int)

@export var player_hp: int = 100
@export var enemy_hp: int = 200
@export var base_gravity: float = 980.0
@export var gravity_ramp_rate: float = 35.0 

var current_state: BattleState = BattleState.PREP
var active_bevo: BevoData
var hit_events: Array[Dictionary] = [] 
var turn_elapsed_time: float = 0.0

func _ready() -> void:
	change_state(BattleState.PREP)

func _process(delta: float) -> void:
	if current_state == BattleState.BALL_IN_PLAY:
		turn_elapsed_time += delta
		var current_gravity = base_gravity + (turn_elapsed_time * gravity_ramp_rate)
		PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, current_gravity)

func change_state(new_state: BattleState) -> void:
	current_state = new_state
	emit_signal("state_changed", new_state)
	match current_state:
		BattleState.PREP: _enter_prep_phase()
		BattleState.BALL_IN_PLAY: print("BALL LAUNCHED")
		BattleState.DAMAGE_CALCULATION: _resolve_damage_queue()
		BattleState.ENEMY_PHASE: _execute_enemy_turn()
		BattleState.CHECK_STATUS: _check_battle_status()

func _enter_prep_phase() -> void:
	hit_events.clear()
	turn_elapsed_time = 0.0
	PhysicsServer2D.area_set_param(get_viewport().find_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY, base_gravity)

func register_board_hit(element_triggered: BevoData.ElementType, flat_dmg: int) -> void:
	if current_state != BattleState.BALL_IN_PLAY: return
	hit_events.append({"element": element_triggered, "damage": flat_dmg})
	
func on_ball_drained() -> void:
	if current_state == BattleState.BALL_IN_PLAY: change_state(BattleState.DAMAGE_CALCULATION)

func _resolve_damage_queue() -> void:
	for event in hit_events:
		enemy_hp = max(0, enemy_hp - event["damage"])
		await get_tree().create_timer(0.4).timeout
		if enemy_hp <= 0: break
	change_state(BattleState.CHECK_STATUS)

func _execute_enemy_turn() -> void:
	player_hp -= 15
	await get_tree().create_timer(0.8).timeout
	change_state(BattleState.CHECK_STATUS)

func _check_battle_status() -> void:
	if enemy_hp <= 0: change_state(BattleState.VICTORY)
	elif player_hp <= 0: change_state(BattleState.GAME_OVER)
	else: change_state(BattleState.PREP)
