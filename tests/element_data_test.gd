extends SceneTree

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func _run() -> void:
	var chart := ReactionTable.new()
	_check(chart.loaded_cells == 143, "All 13 bumper rows and 11 ball columns load")
	_check(is_equal_approx(chart.get_reaction(BevoData.ElementType.WATER, BevoData.ElementType.FIRE).multiplier, 0.5),
		"Asterisked half multiplier parses")
	_check(chart.get_reaction(BevoData.ElementType.EARTH, BevoData.ElementType.WIND).multiplier == 0.0,
		"Zero multiplier remains zero")
	_check(chart.get_reaction(BevoData.ElementType.STEEL, BevoData.ElementType.STEEL).multiplier == 10.0,
		"Steel versus Steel uses chart's tenfold multiplier")
	_check(chart.get_reaction(BevoData.ElementType.FAIRY, BevoData.ElementType.FAIRY).effect_value == 0.4,
		"Fairy versus Fairy heals 40 percent")
	_check(chart.get_reaction(BevoData.ElementType.GHOST, BevoData.ElementType.NORMAL).multiplier == 1.0
		and chart.get_reaction(BevoData.ElementType.GHOST, BevoData.ElementType.NORMAL).effect == "guaranteed_dodge",
		"Ghost matrix row stays intact before status notes")
	var roller := GachaRoller.new()
	var expected_counts := [5, 2, 2, 2, 1]
	for rarity in GachaRoller.RARITIES:
		_check(roller.types_by_rarity.get(rarity, []).size() == expected_counts[rarity],
			"Rarity %d has its intended ball types" % rarity)
	_check(roller.get_type("gold") != null and roller.get_type("gold").score_currency_multiplier == 5.0,
		"Gold resource gives fivefold score and currency")
	for type_id in ["normal", "water", "grass", "fire", "earth", "ice", "wind", "electric", "steel", "fairy", "dark", "gold"]:
		var ball_type := roller.get_type(type_id)
		var file_name := "Earth Bevos Pinball 2.0.png" if type_id == "earth" else "%s Bevo Ball.png" % type_id.capitalize()
		_check(ball_type != null and ball_type.ball_texture != null
			and ball_type.ball_texture.resource_path == "res://art-assets/sprites/bevo-balls/" + file_name,
			"%s ball uses its matching Bevo sprite" % type_id.capitalize())
	print("Element data checks: %d failure(s)." % failures)
	quit(1 if failures > 0 else 0)
