extends Control

# UI node references
@onready var title_label = $UIContainer/TitleLabel

# Called when the node is ready
func _ready():
	if not title_label:
		print("Error: TitleLabel not found")
		return
	if Global.current_user != "":
		title_label.text = "Bienvenido, %s" % Global.current_user
	else:
		title_label.text = "Bienvenido, Jugador"

# Handles play button press
func _on_play_button_pressed():
	var team_management_scene = load("res://Scenes/TeamManagement.tscn").instantiate()
	get_tree().root.add_child(team_management_scene)
	get_tree().current_scene = team_management_scene
	queue_free()
