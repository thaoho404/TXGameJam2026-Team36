class_name RunProfile
extends RefCounted

const SAVE_PATH := "user://pin_roulette_profile.json"
const BOSSES := [200, 1000]
const UPGRADE_KEYS := ["balls", "rerolls", "damage", "hp", "money"]
const BASE_COSTS := {"balls": 20, "rerolls": 15, "damage": 10, "hp": 10, "money": 20}
const MAX_LEVELS := {"balls": 5, "rerolls": 4, "damage": 10, "hp": 10, "money": 5}

var save_path: String = SAVE_PATH
var currency: int = 0
var upgrades: Dictionary = {"balls": 0, "rerolls": 0, "damage": 0, "hp": 0, "money": 0}
var balls_left: int = 0
var boss_index: int = 0
var current_ball: BallType
var rerolls_left: int = 0
var run_damage: int = 0
var run_earned: int = 0
var run_active: bool = false
var _roller := GachaRoller.new()


func load_profile() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	currency = maxi(0, int(parsed.get("currency", 0)))
	var saved_upgrades: Variant = parsed.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for key in UPGRADE_KEYS:
			upgrades[key] = clampi(int(saved_upgrades.get(key, 0)), 0, MAX_LEVELS[key])


func save_profile() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save permanent upgrades: " + save_path)
		return
	file.store_string(JSON.stringify({"currency": currency, "upgrades": upgrades}))


func new_game() -> void:
	currency = 0
	for key in UPGRADE_KEYS:
		upgrades[key] = 0
	save_profile()
	begin_run()


func begin_run() -> void:
	balls_left = 3 + int(upgrades["balls"])
	boss_index = 0
	run_damage = 0
	run_earned = 0
	rerolls_left = int(upgrades["rerolls"])
	current_ball = _roller.roll_ball_type()
	run_active = true


func reroll() -> bool:
	if not run_active or rerolls_left <= 0:
		return false
	rerolls_left -= 1
	current_ball = _roller.roll_ball_type()
	return true


func record_damage(actual_damage: int) -> int:
	if actual_damage <= 0:
		return 0
	run_damage += actual_damage
	var multiplier := (1.0 + 0.25 * int(upgrades["money"]))
	if current_ball != null:
		multiplier *= current_ball.score_currency_multiplier
	var total_reward := int(floor(run_damage * 0.2 * multiplier))
	var reward := maxi(0, total_reward - run_earned)
	run_earned = total_reward
	currency += reward
	save_profile()
	return reward


func upgrade_cost(key: String) -> int:
	if not BASE_COSTS.has(key) or int(upgrades[key]) >= MAX_LEVELS[key]:
		return -1
	return int(BASE_COSTS[key]) * (int(upgrades[key]) + 1)


func buy_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	if cost < 0 or currency < cost:
		return false
	currency -= cost
	upgrades[key] = int(upgrades[key]) + 1
	save_profile()
	return true


func finish_run() -> void:
	run_active = false
	save_profile()
