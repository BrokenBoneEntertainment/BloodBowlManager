extends Control

# UI node references
@onready var title_label = $UIContainer/TitleLabel
@onready var play_button = $UIContainer/PlayButton
@onready var back_to_login_button = $UIContainer/BackToLogin

# Called when the node is ready
func _ready():
	if not title_label or not play_button or not back_to_login_button:
		print("Error: UI nodes not found")
		return
	if Global.current_user != "":
		title_label.text = "Bienvenido, %s" % Global.current_user
	else:
		title_label.text = "Bienvenido, Jugador"
	play_button.text = "Jugar"
	back_to_login_button.text = "Volver al Login"
	
	# Connect signals programmatically
	play_button.pressed.connect(_on_play_button_pressed)
	back_to_login_button.pressed.connect(_on_back_to_login_button_pressed)

# Handles play button press
func _on_play_button_pressed():
	var teams_scene = load("res://Scenes/Teams.tscn").instantiate()
	get_tree().root.add_child(teams_scene)
	get_tree().current_scene = teams_scene
	queue_free()

# Handles back to login button press
func _on_back_to_login_button_pressed():
	var login_scene = load("res://Scenes/Login.tscn").instantiate()
	get_tree().root.add_child(login_scene)
	get_tree().current_scene = login_scene
	queue_free()
