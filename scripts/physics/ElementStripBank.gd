class_name ElementStripBank
extends Node2D

signal element_triggered(element: BevoData.ElementType)

@export_range(1, 20, 1) var passes_required: int = 5
@export_range(0.0, 2.0, 0.05) var pass_cooldown_seconds: float = 0.25

var _pass_count: int = 0
var _last_pass_ms: int = -1000000


func _on_strip_body_entered(body: Node2D) -> void:
	if not body is RigidBody2D or body.name != "BevoBall" or body.freeze:
		return
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_pass_ms < int(pass_cooldown_seconds * 1000.0):
		return
	_last_pass_ms = now_ms
	_pass_count += 1
	_update_strip_brightness()
	if _pass_count < passes_required:
		return

	_pass_count = 0
	var element := randi_range(BevoData.ElementType.FIRE, BevoData.ElementType.DARK) as BevoData.ElementType
	_apply_element_effect(body, element)
	element_triggered.emit(element)
	_update_strip_brightness()


func _apply_element_effect(ball: RigidBody2D, element: BevoData.ElementType) -> void:
	match element:
		BevoData.ElementType.FIRE, BevoData.ElementType.WIND, BevoData.ElementType.ELECTRIC:
			ball.linear_velocity *= 1.35
		BevoData.ElementType.WATER, BevoData.ElementType.GRASS, BevoData.ElementType.ICE:
			ball.linear_velocity *= 0.65
		BevoData.ElementType.EARTH, BevoData.ElementType.STEEL:
			ball.apply_central_impulse(Vector2.UP * 450.0)
		BevoData.ElementType.FAIRY, BevoData.ElementType.DARK:
			ball.apply_central_impulse(Vector2(randf_range(-0.6, 0.6), -1.0).normalized() * 500.0)

	var sprite := ball.get_node_or_null("Sprite2D") as Sprite2D
	if sprite:
		sprite.modulate = _element_color(element) * 1.5
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)


func _update_strip_brightness() -> void:
	var energy := 0.45 + 0.55 * (float(_pass_count) / float(passes_required))
	for strip in get_children():
		var visual := strip.get_node_or_null("Visual") as Polygon2D
		if visual:
			visual.modulate = Color(energy, energy, energy, 1.0)


func _element_color(element: BevoData.ElementType) -> Color:
	match element:
		BevoData.ElementType.FIRE: return Color(1.0, 0.2, 0.05)
		BevoData.ElementType.WATER: return Color(0.1, 0.55, 1.0)
		BevoData.ElementType.ELECTRIC: return Color(1.0, 0.95, 0.1)
		BevoData.ElementType.GRASS: return Color(0.2, 0.9, 0.2)
		BevoData.ElementType.ICE: return Color(0.45, 0.9, 1.0)
		BevoData.ElementType.WIND: return Color(0.75, 1.0, 0.9)
		BevoData.ElementType.EARTH: return Color(0.55, 0.3, 0.1)
		BevoData.ElementType.STEEL: return Color(0.7, 0.75, 0.8)
		BevoData.ElementType.FAIRY: return Color(1.0, 0.45, 0.8)
		BevoData.ElementType.DARK: return Color(0.35, 0.15, 0.5)
		_: return Color.WHITE


func reset_strips() -> void:
	_pass_count = 0
	_last_pass_ms = -1000000
	_update_strip_brightness()
