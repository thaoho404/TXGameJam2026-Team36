# res://scripts/autoload/reaction_table.gd (autoload)
extends Node

enum ElementType {
	NORMAL, FIRE, WATER, GRASS, EARTH, ELECTRIC, ICE, WIND,
	PSYCHIC, GHOST, DARK, STEEL, FAIRY
}

# bumper_type -> ball_type -> multiplier
var multiplier_grid: Dictionary = {}

# bumper_type -> effect id (applies regardless of ball type, unless overridden below)
var bumper_effects := {
	ElementType.ICE: "slow_pinball",
	ElementType.WIND: "speed_pinball",
	ElementType.PSYCHIC: "confuse_enemy",
	ElementType.GHOST: "ghost_buff",
	ElementType.DARK: "dodge_stack",
	ElementType.STEEL: "instant_parry",
	ElementType.FAIRY: "heal_hp",
}

# cell-level overrides: [bumper_type, ball_type] -> {multiplier, effect_value}
var overrides := {
	[ElementType.STEEL, ElementType.STEEL]: {"multiplier": 10.0},
	[ElementType.FAIRY, ElementType.FAIRY]: {"multiplier": 2.0, "effect_value": 0.40},
}

func _ready() -> void:
	_load_grid_from_csv("res://data/reaction_table.csv")

func _load_grid_from_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	var header := file.get_csv_line()  # ["Typing vs typing", "Normal", "Fire", ...]
	var ball_columns := header.slice(1, 12)  # the 11 ball-type column headers

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		var bumper_name := row[0]
		var bumper_type = ElementType.get(bumper_name.to_upper())
		multiplier_grid[bumper_type] = {}

		for i in ball_columns.size():
			var ball_type = ElementType.get(ball_columns[i].to_upper())
			var raw := row[i + 1]
			multiplier_grid[bumper_type][ball_type] = _parse_multiplier(raw)

func _parse_multiplier(raw: String) -> float:
	# strips "x", "+ slows..." suffixes, asterisks, etc — grabs just the leading number
	var num_str := raw.strip_edges().split(" ")[0].replace("x", "").replace("*", "")
	return num_str.to_float()
	
func get_reaction(bumper_type: ElementType, ball_type: ElementType) -> Dictionary:
	var key := [bumper_type, ball_type]
	if overrides.has(key):
		var o = overrides[key]
		return {
			"multiplier": o.get("multiplier", multiplier_grid[bumper_type][ball_type]),
			"effect": bumper_effects.get(bumper_type, ""),
			"effect_value": o.get("effect_value", null),
		}
	return {
		"multiplier": multiplier_grid[bumper_type][ball_type],
		"effect": bumper_effects.get(bumper_type, ""),
		"effect_value": null,
	}
