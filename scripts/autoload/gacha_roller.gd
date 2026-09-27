class_name GachaRoller
extends RefCounted

const TYPE_DIR := "res://resources/ball_types/"
const RARITIES := [
	BallType.Rarity.COMMON,
	BallType.Rarity.UNCOMMON,
	BallType.Rarity.RARE,
	BallType.Rarity.EPIC,
	BallType.Rarity.LEGENDARY,
]
const WEIGHTS := [64.0, 20.0, 10.0, 5.0, 1.0]

var types_by_rarity: Dictionary = {}
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	load_types()


func load_types() -> bool:
	types_by_rarity.clear()
	var directory := DirAccess.open(TYPE_DIR)
	if directory == null:
		push_error("Ball type resources are missing: " + TYPE_DIR)
		return false
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var ball_type := load(TYPE_DIR + file_name) as BallType
			if ball_type != null:
				if not types_by_rarity.has(ball_type.rarity):
					types_by_rarity[ball_type.rarity] = []
				types_by_rarity[ball_type.rarity].append(ball_type)
		file_name = directory.get_next()
	directory.list_dir_end()
	for rarity in RARITIES:
		if not types_by_rarity.has(rarity):
			push_error("No ball type resource for rarity %d" % rarity)
			return false
	return true


func roll_ball_type() -> BallType:
	var roll := rng.randf_range(0.0, 100.0)
	var cumulative := 0.0
	for index in RARITIES.size():
		cumulative += WEIGHTS[index]
		if roll < cumulative:
			var candidates: Array = types_by_rarity.get(RARITIES[index], [])
			if candidates.is_empty():
				return null
			return candidates[rng.randi_range(0, candidates.size() - 1)] as BallType
	return null


func get_type(type_id: String) -> BallType:
	for candidates in types_by_rarity.values():
		for ball_type in candidates:
			if ball_type.id == type_id:
				return ball_type
	return null
