# res://scripts/autoload/gacha_roller.gd (autoload)
extends Node

const RARITY_WEIGHTS := {
	BallType.Rarity.COMMON: 64.0,
	BallType.Rarity.UNCOMMON: 20.0,
	BallType.Rarity.RARE: 10.0,
	BallType.Rarity.EPIC: 5.0,
	BallType.Rarity.LEGENDARY: 1.0,
}

var all_types: Array[BallType] = []
var types_by_rarity: Dictionary = {}  # Rarity -> Array[BallType]

func _ready() -> void:
	_load_all_types()

func _load_all_types() -> void:
	var dir := DirAccess.open("res://resources/ball_types/")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res := load("res://resources/ball_types/" + file_name) as BallType
			all_types.append(res)
			if not types_by_rarity.has(res.rarity):
				types_by_rarity[res.rarity] = []
			types_by_rarity[res.rarity].append(res)
		file_name = dir.get_next()
	dir.list_dir_begin()
	
func roll_ball_type() -> BallType:
	# Step A: pick a rarity tier by weight
	var total_weight := 0.0
	for w in RARITY_WEIGHTS.values():
		total_weight += w
	
	var roll := randf() * total_weight
	var chosen_rarity: BallType.Rarity = BallType.Rarity.COMMON
	var cumulative := 0.0
	for rarity in RARITY_WEIGHTS.keys():
		cumulative += RARITY_WEIGHTS[rarity]
		if roll <= cumulative:
			chosen_rarity = rarity
			break
	
	# Step B: pick a random type within that tier
	var candidates: Array = types_by_rarity.get(chosen_rarity, [])
	if candidates.is_empty():
		push_error("No BallType resources found for rarity: %s" % chosen_rarity)
		return null
	
	return candidates[randi() % candidates.size()]
	
