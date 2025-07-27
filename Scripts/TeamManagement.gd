extends Control

# Team data
var team = []  # List of players (24 positions, null for empty)
var position_limits = {
	"Fighter": 8,
	"Defender": 16,
	"Thrower": 4,
	"Runner": 4
}
var first_names = []  # List of first names
var titles = []  # List of titles
var delete_mode = false  # State of delete mode
var delete_index = -1  # Index of player to delete

# UI node references
@onready var title_label = $UIContainer/TitleLabel
@onready var item_list = $UIContainer/ItemList
@onready var warning_label = $UIContainer/WarningLabel
@onready var custom_name_input = $UIContainer/CustomNameInput
@onready var position_selector = $UIContainer/PositionSelector
@onready var hire_player_button = $UIContainer/HirePlayerButton
@onready var delete_player_button = $UIContainer/DeletePlayerButton
@onready var clear_name_button = $UIContainer/ClearNameButton
@onready var match_strategy = $UIContainer/MatchStrategy
@onready var back_button = $UIContainer/BackButton
@onready var play_match_button = $UIContainer/PlayMatchButton
@onready var confirm_delete_popup = $UIContainer/ConfirmDeletePopup
@onready var confirm_delete_button = $UIContainer/ConfirmDeletePopup/PopupContainer/ButtonContainer/ConfirmDeleteButton
@onready var cancel_delete_button = $UIContainer/ConfirmDeletePopup/PopupContainer/ButtonContainer/CancelDeleteButton
@onready var delete_popup_label = $UIContainer/ConfirmDeletePopup/PopupContainer/Label

# Called when the node is ready
func _ready():
	var file = FileAccess.open("res://Resources/player_names.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		first_names = json["first_names"]
		titles = json["titles"]
		file.close()
	else:
		show_message("Error: No se pudo cargar player_names.json")
	
	if not title_label or not item_list or not warning_label or not custom_name_input or not position_selector or not hire_player_button or not delete_player_button or not clear_name_button or not match_strategy or not back_button or not play_match_button or not confirm_delete_popup or not confirm_delete_button or not cancel_delete_button or not delete_popup_label:
		show_message("Error: UI nodes not found")
		return
	
	title_label.text = "Equipo: %s" % Global.current_team
	warning_label.text = ""
	custom_name_input.text = ""
	hire_player_button.text = "Contratar Jugador"
	delete_player_button.text = "Eliminar Jugador"
	clear_name_button.text = "Limpiar Nombre"
	back_button.text = "Volver"
	play_match_button.text = "Jugar Partido"
	match_strategy.clear()
	match_strategy.add_item("Ofensiva", 0)
	match_strategy.add_item("Defensiva", 1)
	match_strategy.add_item("Equilibrada", 2)
	position_selector.clear()
	position_selector.add_item("Fighter", 0)
	position_selector.add_item("Defender", 1)
	position_selector.add_item("Thrower", 2)
	position_selector.add_item("Runner", 3)
	
	load_player_team()
	update_team_list()
	
	# Connect signals programmatically
	hire_player_button.pressed.connect(_on_hire_player_button_pressed)
	delete_player_button.pressed.connect(_on_delete_player_button_pressed)
	clear_name_button.pressed.connect(_on_clear_name_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	play_match_button.pressed.connect(_on_play_match_button_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_button_pressed)
	cancel_delete_button.pressed.connect(_on_cancel_delete_button_pressed)
	item_list.item_clicked.connect(_on_item_list_item_clicked)

# Loads the player's team from user-specific JSON
func load_player_team():
	var file_path = "res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, Global.current_team]
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		team = json.get("players", [])
		file.close()
		# Ensure team has 24 positions
		if team.size() != 24:
			print("Warning: Team size is %d, resizing to 24" % team.size())
			team.resize(24)
			for i in range(24):
				team[i] = team[i] if i < team.size() and team[i] != null else null
			save_player_team()
		print("Debug: Loaded team: ", team)
	else:
		print("No team file found at %s, initializing new team" % file_path)
		team.resize(24)
		for i in range(24):
			team[i] = null
		save_player_team()

# Saves the player's team to user-specific JSON
func save_player_team():
	var dir = DirAccess.open("res://Resources/")
	if not dir.dir_exists("Teams"):
		dir.make_dir("Teams")
	var file = FileAccess.open("res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, Global.current_team], FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players": team}, "\t"))
		file.close()

# Handles hire player button press
func _on_hire_player_button_pressed():
	if get_player_count() >= 24:
		show_message("¡Equipo completo! No puedes contratar más jugadores.")
		return
	var new_player = create_player()
	if new_player:
		var index = team.find(null)
		if index != -1:
			team[index] = new_player
			update_team_list()
			save_player_team()
			custom_name_input.text = ""
			show_message("Jugador %s contratado." % new_player.name)
		else:
			show_message("Error: No hay posiciones disponibles (índice no encontrado).")
			print("Debug: Team state: ", team)
	# Error messages are handled in create_player

# Handles delete player button press
func _on_delete_player_button_pressed():
	delete_mode = true
	delete_index = -1
	delete_player_button.text = "PULSA FUERA PARA CANCELAR"
	item_list.deselect_all()
	show_message("Selecciona un jugador para eliminar.")

# Handles back button press
func _on_back_button_pressed():
	var teams_scene = load("res://Scenes/Teams.tscn").instantiate()
	get_tree().root.add_child(teams_scene)
	get_tree().current_scene = teams_scene
	queue_free()

# Handles play match button press
func _on_play_match_button_pressed():
	var player_count = get_player_count()
	if player_count < 11:
		show_message("Necesitas al menos 11 jugadores para jugar un partido. Tienes: %d" % player_count)
		return
	# Mark the first 11 non-null players as playing
	var active_count = 0
	for i in range(team.size()):
		if team[i] != null and active_count < 11 and team[i].state != "herido":
			team[i].state = "playing"
			active_count += 1
		elif team[i] != null and team[i].state != "herido":
			team[i].state = "healthy"
	save_player_team()
	var match_scene = load("res://Scenes/Match.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()

# Creates a new player with position, name, and stats
func create_player():
	if not position_selector:
		show_message("Error: PositionSelector no encontrado.")
		return null
	var selected_index = position_selector.selected
	if selected_index == -1:
		show_message("Selecciona una posición.")
		return null
	var position = position_selector.get_item_text(selected_index)
	if can_add_position(position):
		var name = ""
		var custom_name = custom_name_input.text.strip_edges()
		if custom_name != "":
			name = custom_name
			if team.any(func(p): return p != null and p.name == name):
				show_message("El nombre %s ya está en uso." % name)
				return null
		else:
			var available_names = get_available_name_combinations()
			if available_names.is_empty():
				show_message("No hay nombres predefinidos disponibles.")
				return null
			name = available_names[randi() % available_names.size()]
		var player = {
			"name": name,
			"position": position,
			"number": 0,  # Assigned in update_team_list
			"race": "Human",
			"stats": get_stats_for_position(position),
			"state": "healthy"
		}
		return player
	else:
		show_message("Límite de %s alcanzado (%d/%d)." % [position, get_position_count(position), position_limits[position]])
		return null

# Handles clear name button press
func _on_clear_name_button_pressed():
	custom_name_input.text = ""
	show_message("Nombre limpiado.")

# Handles item list click for deletion
func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	if mouse_button_index == MOUSE_BUTTON_LEFT and index >= 0 and index < team.size() and delete_mode and team[index] != null:
		delete_index = index
		delete_popup_label.text = "¿Eliminar a %s?" % team[index].name
		confirm_delete_popup.popup_centered()
		item_list.deselect_all()

# Handles input for deselecting outside ItemList
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var item_list_rect = item_list.get_global_rect()
		if not item_list_rect.has_point(event.global_position):
			item_list.deselect_all()
			if delete_mode:
				delete_mode = false
				delete_index = -1
				delete_player_button.text = "Eliminar Jugador"
				confirm_delete_popup.hide()
				show_message("Eliminación cancelada.")
			update_team_list()

# Handles confirm delete button press
func _on_confirm_delete_button_pressed():
	if delete_index >= 0 and delete_index < team.size() and team[delete_index] != null:
		var player_name = team[delete_index].name
		team[delete_index] = null
		update_team_list()
		save_player_team()
		show_message("Jugador %s eliminado." % player_name)
	delete_mode = false
	delete_index = -1
	delete_player_button.text = "Eliminar Jugador"
	confirm_delete_popup.hide()
	item_list.deselect_all()

# Handles cancel delete button press
func _on_cancel_delete_button_pressed():
	delete_mode = false
	delete_index = -1
	delete_player_button.text = "Eliminar Jugador"
	confirm_delete_popup.hide()
	show_message("Eliminación cancelada.")
	item_list.deselect_all()

# Displays a temporary message
func show_message(message: String):
	warning_label.text = message
	await get_tree().create_timer(3.0).timeout
	warning_label.text = ""

# Returns available name combinations
func get_available_name_combinations():
	var combinations = []
	for fname in first_names:
		for title in titles:
			var full_name = fname + " " + title
			if not team.any(func(p): return p != null and p.name == full_name):
				combinations.append(full_name)
	return combinations

# Checks if a player can be added to the given position
func can_add_position(position):
	var count = get_position_count(position)
	return count < position_limits[position]

# Counts players in a specific position
func get_position_count(position):
	var count = 0
	for player in team:
		if player != null and player.position == position:
			count += 1
	return count

# Returns stats for a given position
func get_stats_for_position(position):
	match position:
		"Fighter":
			return {"strength": 4, "agility": 3, "armor": 8, "movement": 6}
		"Defender":
			return {"strength": 3, "agility": 2, "armor": 9, "movement": 5}
		"Thrower":
			return {"strength": 2, "agility": 4, "armor": 7, "movement": 6}
		"Runner":
			return {"strength": 2, "agility": 3, "armor": 7, "movement": 7}
	return {}

# Counts non-null players
func get_player_count():
	var count = 0
	for player in team:
		if player != null:
			count += 1
	return count

# Updates ItemList with players and empty positions
func update_team_list():
	item_list.clear()
	for i in range(team.size()):
		if team[i] != null:
			team[i].number = i + 1
			var text = "#%d - %s - %s - %s - %s (F: %d, A: %d, Arm: %d, M: %d)" % [
				i + 1, team[i].name, team[i].position, team[i].race, team[i].state.capitalize(),
				team[i].stats.strength, team[i].stats.agility,
				team[i].stats.armor, team[i].stats.movement
			]
			item_list.add_item(text, null, true)
			if team[i].state == "herido":
				item_list.set_item_custom_fg_color(i, Color.RED)
			else:
				item_list.set_item_custom_fg_color(i, Color.WHITE)
		else:
			item_list.add_item("Vacío #%d" % [i + 1], null, true)
	item_list.deselect_all()
