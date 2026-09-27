class_name ReactionTable
extends RefCounted

# CSV rows are bumper elements; columns are ball elements.
const CSV_PATH := "res://data/TXGJ 2026 Reactions - Sheet1.csv"
const EFFECTS := {
	BevoData.ElementType.ICE: "slow_ball",
	BevoData.ElementType.WIND: "speed_ball",
	BevoData.ElementType.PSYCHIC: "confuse_enemy",
	BevoData.ElementType.GHOST: "guaranteed_dodge",
	BevoData.ElementType.DARK: "dodge_stack",
	BevoData.ElementType.STEEL: "instant_parry",
	BevoData.ElementType.FAIRY: "heal_hp",
}

var multipliers: Dictionary = {}
var loaded_cells: int = 0


func _init() -> void:
	load_csv()


func load_csv() -> bool:
	multipliers.clear()
	loaded_cells = 0
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read reaction chart: " + CSV_PATH)
		return false
	var columns := file.get_csv_line()
	if columns.size() < 2 or columns[0].strip_edges() != "Typing vs typing":
		push_error("Reaction chart header is missing or changed.")
		return false
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var bumper_name := row[0].strip_edges().to_upper()
		if bumper_name.begins_with("^") or bumper_name == "STATUS NAME":
			break
		if not BevoData.ElementType.has(bumper_name):
			continue
		var bumper_element: int = BevoData.ElementType[bumper_name]
		multipliers[bumper_element] = {}
		for column in range(1, mini(columns.size(), row.size())):
			var ball_name := columns[column].strip_edges().to_upper()
			if not BevoData.ElementType.has(ball_name):
				continue
			var raw: String = row[column].strip_edges()
			var prefix := raw.get_slice(" ", 0).trim_prefix("*").trim_suffix("x")
			if not prefix.is_valid_float():
				push_error("Invalid reaction multiplier: %s / %s: %s" % [bumper_name, ball_name, raw])
				continue
			multipliers[bumper_element][BevoData.ElementType[ball_name]] = prefix.to_float()
			loaded_cells += 1
	return loaded_cells == 143


func get_reaction(bumper_element: BevoData.ElementType, ball_element: BevoData.ElementType) -> Dictionary:
	# Gold has no chart column; it uses Normal's column before its own bonus.
	var chart_ball: int = BevoData.ElementType.NORMAL if ball_element == BevoData.ElementType.GOLD else ball_element
	var row: Dictionary = multipliers.get(bumper_element, {})
	var multiplier: float = row.get(chart_ball, 1.0)
	var effect: String = EFFECTS.get(bumper_element, "")
	var effect_value: float = 0.0
	match bumper_element:
		BevoData.ElementType.ICE, BevoData.ElementType.WIND, BevoData.ElementType.PSYCHIC, BevoData.ElementType.DARK:
			effect_value = 0.2
		BevoData.ElementType.GHOST, BevoData.ElementType.STEEL:
			effect_value = 1.0
		BevoData.ElementType.FAIRY:
			effect_value = 0.4 if chart_ball == BevoData.ElementType.FAIRY else 0.2
	return {"multiplier": multiplier, "effect": effect, "effect_value": effect_value}
