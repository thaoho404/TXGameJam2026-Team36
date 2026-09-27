class_name TurnManager
extends Node

enum BattleState { IDLE, PREP, BALL_IN_PLAY, DAMAGE_CALCULATION, ENEMY_PHASE, GAME_OVER, VICTORY }

signal state_changed(new_state: BattleState)
signal battle_updated()
signal turn_combo_updated(current_hits: int, preview_damage: int)
signal turn_ready()
signal battle_finished(player_won: bool)
signal damage_dealt(amount: int)
signal ball_speed_changed(multiplier: float)

@export_range(1, 999999, 1) var player_max_hp: int = 100
@export_range(1, 999999, 1) var enemy_max_hp: int = 200
@export_range(0, 999999, 1) var enemy_base_damage: int = 15
@export_range(0.0, 5.0, 0.05) var player_attack_delay: float = 0.5
@export_range(0.0, 5.0, 0.05) var enemy_attack_delay: float = 0.8
@export_range(1.0, 60.0, 0.5) var charge_interval: float = 15.0
@export_range(0, 9999, 1) var charge_bonus: int = 5
@export_range(0.1, 2.0, 0.05) var parry_window_seconds: float = 0.35

var current_state: BattleState = BattleState.IDLE
var player_hp: int = 100
var enemy_hp: int = 200
var turn_score: int = 0
var current_hits: int = 0
var turn_number: int = 0
var last_player_damage: int = 0
var last_enemy_damage: int = 0
var total_damage_dealt: int = 0
var balls_left: int = -1 # -1 keeps standalone battle scenes unrestricted.
var selected_ball: BallType
var flat_damage: int = 0
var charged_stacks: int = 0
var parried_stacks: int = 0
var ball_speed_multiplier: float = 1.0
var _charge_elapsed: float = 0.0
var _parry_window_remaining: float = 0.0
var _dodge_stacks: float = 0.0
var _guaranteed_dodge: bool = false
var _instant_parry: bool = false
var _confused_enemy: bool = false
var _rng := RandomNumberGenerator.new()
var _reactions := ReactionTable.new()

# Invalidates delayed attacks when the player leaves or starts another battle.
var _battle_id: int = 0


func _ready() -> void:
	_rng.randomize()
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
	_reset_effects()
	_prepare_next_turn()


func start_next_opponent(next_hp: int, next_base_damage: int = 15) -> void:
	_battle_id += 1
	enemy_max_hp = maxi(1, next_hp)
	enemy_hp = enemy_max_hp
	enemy_base_damage = maxi(0, next_base_damage)
	last_player_damage = 0
	last_enemy_damage = 0
	_prepare_next_turn()


func stop_battle() -> void:
	_battle_id += 1
	_reset_effects()
	_change_state(BattleState.IDLE)


func _reset_effects() -> void:
	charged_stacks = 0
	parried_stacks = 0
	_charge_elapsed = 0.0
	_parry_window_remaining = 0.0
	ball_speed_multiplier = 1.0
	_dodge_stacks = 0.0
	_guaranteed_dodge = false
	_instant_parry = false
	_confused_enemy = false


func on_ball_launched() -> void:
	if current_state != BattleState.PREP:
		return
	if balls_left == 0:
		_finish_battle(false)
		return
	if balls_left > 0:
		balls_left -= 1
	turn_number += 1
	_charge_elapsed = 0.0
	charged_stacks = 0
	parried_stacks = 0
	_parry_window_remaining = 0.0
	ball_speed_multiplier = 1.0
	_change_state(BattleState.BALL_IN_PLAY)


func _process(delta: float) -> void:
	if current_state != BattleState.BALL_IN_PLAY:
		return
	_charge_elapsed += delta
	_parry_window_remaining = maxf(0.0, _parry_window_remaining - delta)
	while _charge_elapsed >= charge_interval:
		_charge_elapsed -= charge_interval
		charged_stacks += 1
		_parry_window_remaining = parry_window_seconds
		battle_updated.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		try_parry()


func try_parry() -> bool:
	if current_state != BattleState.BALL_IN_PLAY or _parry_window_remaining <= 0.0 or parried_stacks >= charged_stacks:
		return false
	parried_stacks += 1
	_parry_window_remaining = 0.0
	battle_updated.emit()
	return true


func register_board_hit(element: BevoData.ElementType, points: int) -> void:
	if current_state != BattleState.BALL_IN_PLAY or points <= 0:
		return
	var ball_element := BevoData.ElementType.NORMAL
	if selected_ball != null:
		ball_element = selected_ball.element
	var reaction := _reactions.get_reaction(element, ball_element)
	var multiplier: float = reaction.multiplier
	var strength := 1.0 if selected_ball == null else selected_ball.reaction_strength_mult
	if strength > 1.0:
		multiplier = maxf(0.0, 1.0 + (multiplier - 1.0) * strength)
	var score_multiplier := 1.0 if selected_ball == null else selected_ball.score_currency_multiplier
	current_hits += 1
	turn_score += roundi(points * multiplier * score_multiplier)
	_apply_reaction(reaction, strength)
	turn_combo_updated.emit(current_hits, turn_score)
	battle_updated.emit()


func _apply_reaction(reaction: Dictionary, strength: float) -> void:
	var amount: float = reaction.effect_value * strength
	match String(reaction.effect):
		"slow_ball":
			ball_speed_multiplier = maxf(0.2, ball_speed_multiplier - amount)
			ball_speed_changed.emit(ball_speed_multiplier)
		"speed_ball":
			ball_speed_multiplier += amount
			ball_speed_changed.emit(ball_speed_multiplier)
		"heal_hp":
			player_hp = mini(player_max_hp, player_hp + roundi(player_max_hp * amount))
		"dodge_stack":
			_dodge_stacks += amount
		"guaranteed_dodge":
			_guaranteed_dodge = true
		"instant_parry":
			_instant_parry = true
		"confuse_enemy":
			_confused_enemy = true


func on_ball_drained() -> void:
	if current_state != BattleState.BALL_IN_PLAY:
		return

	var resolving_battle: int = _battle_id
	# The entire final score is applied once. HP is clamped against overkill.
	var attack_damage := turn_score + flat_damage if turn_score > 0 else 0
	last_player_damage = mini(attack_damage, enemy_hp)
	enemy_hp = maxi(0, enemy_hp - attack_damage)
	total_damage_dealt += last_player_damage
	damage_dealt.emit(last_player_damage)
	if selected_ball != null and selected_ball.lifesteal > 0:
		player_hp = mini(player_max_hp, player_hp + roundi(last_player_damage * selected_ball.lifesteal))
	ball_speed_multiplier = 1.0
	ball_speed_changed.emit(1.0)
	_change_state(BattleState.DAMAGE_CALCULATION)

	await get_tree().create_timer(player_attack_delay).timeout
	if not _can_resume(resolving_battle):
		return
	if enemy_hp == 0:
		_finish_battle(true)
		return

	var charged_damage := 0 if _instant_parry else (charged_stacks - parried_stacks) * charge_bonus
	var enemy_attack := enemy_base_damage + charged_damage
	if _confused_enemy:
		enemy_hp = maxi(0, enemy_hp - roundi(enemy_attack * 0.2))
	var dodge_chance := _dodge_stacks
	if selected_ball != null:
		dodge_chance += selected_ball.dodge_chance
	if _guaranteed_dodge or _rng.randf() < minf(1.0, dodge_chance):
		enemy_attack = 0
	if selected_ball != null:
		enemy_attack = roundi(enemy_attack * (1.0 - selected_ball.damage_reduction))
	last_enemy_damage = mini(enemy_attack, player_hp)
	player_hp = maxi(0, player_hp - enemy_attack)
	_dodge_stacks = 0.0
	_guaranteed_dodge = false
	_instant_parry = false
	_confused_enemy = false
	_change_state(BattleState.ENEMY_PHASE)

	await get_tree().create_timer(enemy_attack_delay).timeout
	if not _can_resume(resolving_battle):
		return
	if player_hp == 0:
		_finish_battle(false)
		return
	if enemy_hp == 0:
		_finish_battle(true)
		return
	if balls_left == 0:
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
