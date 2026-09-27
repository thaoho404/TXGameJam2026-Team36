class_name TurnManager
extends Node

enum BattleState { IDLE, PREP, BALL_IN_PLAY, DAMAGE_CALCULATION, ENEMY_PHASE, GAME_OVER, VICTORY }

signal state_changed(new_state: BattleState)
signal battle_updated()
signal turn_combo_updated(current_hits: int, preview_damage: int)
signal turn_ready()
signal battle_finished(player_won: bool)

@export_range(1, 999999, 1) var player_max_hp: int = 100
@export_range(1, 999999, 1) var enemy_max_hp: int = 200
@export_range(0, 999999, 1) var enemy_base_damage: int = 15
@export_range(0.0, 5.0, 0.05) var player_attack_delay: float = 0.5
@export_range(0.0, 5.0, 0.05) var enemy_attack_delay: float = 0.8

var current_state: BattleState = BattleState.IDLE
var player_hp: int = 100
var enemy_hp: int = 200
var turn_score: int = 0
var current_hits: int = 0
var turn_number: int = 0
var last_player_damage: int = 0
var last_enemy_damage: int = 0
var total_damage_dealt: int = 0

# Invalidates delayed attacks when the player leaves or starts another battle.
var _battle_id: int = 0


func _ready() -> void:
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp


func start_battle() -> void:
	_battle_id += 1
	player_hp = player_max_hp
	enemy_hp = enemy_max_hp
	turn_number = 0
	last_player_damage = 0
	last_enemy_damage = 0
	total_damage_dealt = 0
	_prepare_next_turn()


func stop_battle() -> void:
	_battle_id += 1
	_change_state(BattleState.IDLE)


func on_ball_launched() -> void:
	if current_state != BattleState.PREP:
		return
	turn_number += 1
	_change_state(BattleState.BALL_IN_PLAY)


func register_board_hit(_element: BevoData.ElementType, points: int) -> void:
	if current_state != BattleState.BALL_IN_PLAY or points <= 0:
		return
	current_hits += 1
	turn_score += points
	turn_combo_updated.emit(current_hits, turn_score)
	battle_updated.emit()


func on_ball_drained() -> void:
	if current_state != BattleState.BALL_IN_PLAY:
		return

	var resolving_battle: int = _battle_id
	# The entire final score is applied once. HP is clamped against overkill.
	last_player_damage = mini(turn_score, enemy_hp)
	enemy_hp = maxi(0, enemy_hp - turn_score)
	total_damage_dealt += last_player_damage
	_change_state(BattleState.DAMAGE_CALCULATION)

	await get_tree().create_timer(player_attack_delay).timeout
	if not _can_resume(resolving_battle):
		return
	if enemy_hp == 0:
		_finish_battle(true)
		return

	last_enemy_damage = mini(enemy_base_damage, player_hp)
	player_hp = maxi(0, player_hp - enemy_base_damage)
	_change_state(BattleState.ENEMY_PHASE)

	await get_tree().create_timer(enemy_attack_delay).timeout
	if not _can_resume(resolving_battle):
		return
	if player_hp == 0:
		_finish_battle(false)
		return

	_prepare_next_turn()


func _prepare_next_turn() -> void:
	turn_score = 0
	current_hits = 0
	turn_combo_updated.emit(current_hits, turn_score)
	_change_state(BattleState.PREP)
	turn_ready.emit()


func _finish_battle(player_won: bool) -> void:
	_change_state(BattleState.VICTORY if player_won else BattleState.GAME_OVER)
	battle_finished.emit(player_won)


func _change_state(new_state: BattleState) -> void:
	current_state = new_state
	state_changed.emit(new_state)
	battle_updated.emit()


func _can_resume(resolving_battle: int) -> bool:
	return is_inside_tree() and resolving_battle == _battle_id


func _exit_tree() -> void:
	_battle_id += 1
