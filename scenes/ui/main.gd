extends Control

@onready var title_screen: Control = $MainMenu/Panel
@onready var upgrade_screen: Control = $MainMenu/UpgradeMenu
@onready var credit_screen: Control = $MainMenu/CreditMenu
@onready var game_screen: Control = $MainMenu/GamePlay

func _ready() -> void:
	show_screen(title_screen)

func show_screen(screen: Control) -> void:
	title_screen.hide()
	upgrade_screen.hide()
	credit_screen.hide()
	game_screen.hide()
	screen.show()

func _on_play_button_pressed() -> void:
	show_screen(game_screen)

func _on_upgrade_button_pressed() -> void:
	show_screen(upgrade_screen)

func _on_credits_button_pressed() -> void:
	show_screen(credit_screen)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

func _on_back_button_pressed() -> void:
	show_screen(title_screen)
