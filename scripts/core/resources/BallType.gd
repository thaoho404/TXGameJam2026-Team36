class_name BallType
extends Resource

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

@export var id: String              # "fire", "ice", "gold" - used for lookups/save data
@export var display_name: String    # "Fire", "Ice", "Gold"
@export var rarity: Rarity
@export var element: BevoData.ElementType = BevoData.ElementType.NORMAL
@export var ball_texture: Texture2D
@export_multiline var description: String

## Gameplay effects - leave at default (0 or false) if this type doesn't use it
@export_group("Effects")
@export var damage_reduction: float = 0.0          # Ice 0.10, Steel 0.20
@export var speed_multiplier: float = 1.0          # Wind 1.2, Electric 1.4
@export var reaction_strength_mult: float = 1.0    # Electric's "stronger reactions"
@export var lifesteal: float = 0.0                 # Fairy 0.05
@export var dodge_chance: float = 0.0               # Dark 0.20
@export var score_currency_multiplier: float = 1.0 # Gold 5.0
