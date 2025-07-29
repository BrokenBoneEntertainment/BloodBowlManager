extends Control

var team = []  # List of players (16 positions, null for empty)
var position_limits = {
	"Lineman": 16,
	"Thrower": 2,
	"Catcher": 4,
	"Blitzer": 4,
	"Ogre": 1,
	"Halfling": 3
}
var first_names = []
var titles = []
var delete_mode = false
var delete_index = -1

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
@onready var details_popup = $UIContainer/DetailsPopup
@onready var details_label = $UIContainer/DetailsPopup/PopupContainer/DetailsLabel

func _ready():
	var file = FileAccess.open("res://Resources/player_names.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		first_names = json["first_names"]
		titles = json["titles"]
		file.close()
	else:
		show_message("Error: No se pudo cargar player_names.json")
	
	if not title_label or not item_list or not warning_label or not custom_name_input or not position_selector or not hire_player_button or not delete_player_button or not clear_name_button or not match_strategy or not back_button or not play_match_button or not confirm_delete_popup or not confirm_delete_button or not cancel_delete_button or not delete_popup_label or not details_popup or not details_label:
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
	position_selector.add_item("Lineman", 0)
	position_selector.add_item("Thrower", 1)
	position_selector.add_item("Catcher", 2)
	position_selector.add_item("Blitzer", 3)
	position_selector.add_item("Ogre", 4)
	position_selector.add_item("Halfling", 5)
	
	team.resize(16)  # Inicializar con 16 slots
	load_player_team()
	update_team_list()
	
	hire_player_button.pressed.connect(_on_hire_player_button_pressed)
	delete_player_button.pressed.connect(_on_delete_player_button_pressed)
	clear_name_button.pressed.connect(_on_clear_name_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	play_match_button.pressed.connect(_on_play_match_button_pressed)
	confirm_delete_button.pressed.connect(_on_confirm_delete_button_pressed)
	cancel_delete_button.pressed.connect(_on_cancel_delete_button_pressed)
	item_list.item_clicked.connect(_on_item_list_item_clicked)
	
	if details_popup:
		details_popup.hide()
	else:
		print("Error: DetailsPopup no encontrado")

func load_player_team():
	var sanitized_team_name = Global.sanitize_filename(Global.current_team)
	var file_path = "res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, sanitized_team_name]
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary and json.has("players"):
			team = json.players
			if team.size() != 16:
				print("Warning: Team size is %d, resizing to 16" % team.size())
				var temp_team = []
				temp_team.resize(16)
				for i in min(16, team.size()):
					temp_team[i] = team[i] if team[i] != null else null
				team = temp_team
			print("Debug: Loaded team: ", team)
		file.close()
	else:
		show_message("Error: El archivo del equipo no existe. Crea el equipo en la escena Teams.")
		# No inicializar aquí, dejar que Teams lo maneje

func save_player_team():
	var sanitized_team_name = Global.sanitize_filename(Global.current_team)
	var file_path = "res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, sanitized_team_name]
	var dir = DirAccess.open("res://Resources/")
	if not dir.dir_exists("Teams"):
		dir.make_dir("Teams")
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players": team}, "\t"))
		file.close()

func _on_hire_player_button_pressed():
	if get_player_count() >= 16:
		show_message("¡Equipo completo! No puedes contratar más jugadores (máximo 16).")
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
			show_message("Error: No hay posiciones disponibles.")
			print("Debug: Team state: ", team)

func _on_delete_player_button_pressed():
	delete_mode = true
	delete_index = -1
	delete_player_button.text = "PULSA FUERA PARA CANCELAR"
	item_list.deselect_all()
	show_message("Selecciona un jugador para eliminar.")

func _on_back_button_pressed():
	save_player_team()
	var main_scene = load("res://Scenes/Main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	queue_free()

func _on_play_match_button_pressed():
	var player_count = get_player_count()
	if player_count < 11:
		show_message("Necesitas al menos 11 jugadores para jugar un partido. Tienes: %d" % player_count)
		return
	save_player_team()
	var match_scene = load("res://Scenes/Match.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()

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
			"number": 0,
			"race": "Human",
			"attributes": get_attributes_for_position(position),
			"skills": get_skills_for_position(position),
			"state": "healthy"  # Solo "healthy" o "herido"
		}
		return player
	else:
		show_message("Límite de %s alcanzado (%d/%d)." % [position, get_position_count(position), position_limits[position]])
		return null

func _on_clear_name_button_pressed():
	custom_name_input.text = ""
	show_message("Nombre limpiado.")

func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	if mouse_button_index == MOUSE_BUTTON_LEFT and index >= 0 and index < team.size() and team[index] != null:
		if delete_mode:
			delete_index = index
			delete_popup_label.text = "¿Eliminar a %s?" % team[index].name
			confirm_delete_popup.popup_centered()
			item_list.deselect_all()
		else:
			if details_popup and details_label:
				details_label.text = "Nombre: %s\nPosición: %s\nHabilidades: %s\nAtributos: MA %d, ST %d, AG %d+, PA %d+, AV %d+\nEstado: %s" % [
					team[index].name, team[index].position, ", ".join(team[index].skills),
					team[index].attributes.MA, team[index].attributes.ST, team[index].attributes.AG,
					team[index].attributes.PA, team[index].attributes.AV,
					"Sano" if team[index].state == "healthy" else "Herido"
				]
				details_popup.popup_centered()
			else:
				print("Error: DetailsPopup o DetailsLabel no encontrados")

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
			if details_popup:
				details_popup.hide()

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

func _on_cancel_delete_button_pressed():
	delete_mode = false
	delete_index = -1
	delete_player_button.text = "Eliminar Jugador"
	confirm_delete_popup.hide()
	show_message("Eliminación cancelada.")
	item_list.deselect_all()

func show_message(message: String):
	warning_label.text = message
	await get_tree().create_timer(3.0).timeout
	warning_label.text = ""

func get_available_name_combinations():
	var combinations = []
	for fname in first_names:
		for title in titles:
			var full_name = fname + " " + title
			if not team.any(func(p): return p != null and p.name == full_name):
				combinations.append(full_name)
	return combinations

func can_add_position(position):
	var count = get_position_count(position)
	return count < position_limits[position] and get_player_count() < 16

func get_position_count(position):
	var count = 0
	for player in team:
		if player != null and player.position == position:
			count += 1
	return count

func get_player_count():
	var count = 0
	for player in team:
		if player != null:
			count += 1
	return count

func get_attributes_for_position(position):
	match position:
		"Lineman":
			return {"MA": 6, "ST": 3, "AG": 3, "PA": 4, "AV": 8}
		"Thrower":
			return {"MA": 6, "ST": 3, "AG": 3, "PA": 2, "AV": 8}
		"Catcher":
			return {"MA": 8, "ST": 2, "AG": 2, "PA": 4, "AV": 7}
		"Blitzer":
			return {"MA": 7, "ST": 3, "AG": 3, "PA": 4, "AV": 8}
		"Ogre":
			return {"MA": 5, "ST": 5, "AG": 4, "PA": 5, "AV": 10}
		"Halfling":
			return {"MA": 5, "ST": 1, "AG": 3, "PA": 5, "AV": 6}
	return {}

func get_skills_for_position(position):
	match position:
		"Lineman":
			return []
		"Thrower":
			return ["Sure Hands", "Pass"]
		"Catcher":
			return ["Catch", "Dodge"]
		"Blitzer":
			return ["Block"]
		"Ogre":
			return ["Bone-head", "Mighty Blow", "Thick Skull", "Throw Team-mate"]
		"Halfling":
			return ["Dodge", "Right Stuff", "Stunty"]
	return []

func update_team_list():
	item_list.clear()
	for i in range(team.size()):
		if team[i] != null:
			team[i].number = i + 1
			var text = "#%d - %s - %s" % [i + 1, team[i].name, team[i].position]
			item_list.add_item(text, null, true)
			if team[i].state == "herido":
				item_list.set_item_custom_fg_color(i, Color.RED)
			else:  # "healthy"
				item_list.set_item_custom_fg_color(i, Color.WHITE)
		else:
			item_list.add_item("Vacío #%d" % [i + 1], null, true)
	item_list.deselect_all()
