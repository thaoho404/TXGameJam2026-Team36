class_name BevoData
extends Resource

enum ElementType {
	NORMAL, FIRE, WATER, ELECTRIC, GRASS, ICE, WIND, EARTH, STEEL, FAIRY, DARK, GOLD,
	PSYCHIC, GHOST
}

@export var bevo_name: String = "Standard Bevo"
@export var base_damage: int = 10
@export var elements: Array[ElementType] = [ElementType.NORMAL]
@export var icon: Texture2D
