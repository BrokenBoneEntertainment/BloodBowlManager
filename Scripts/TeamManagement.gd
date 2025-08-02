extends Control

var team = []
var team_file_path = ""
var template_data = {}
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
@onready var gold_label = $UIContainer/GoldLabel

func _ready():
	if not Global.current_team or not Global.current_user:
		Global.current_user = "default_user"
		Global.current_team = "Default Team"
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
	gold_label.text = "Oro: 0"  # Se actualizará en load_team()

	team.resize(16)
	load_team()
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

func load_team():
	var user_dir = "res://Resources/UserTeams/%s/" % Global.current_user
	team_file_path = "%splayer_team_%s_%s.json" % [user_dir, Global.current_user, Global.sanitize_filename(Global.current_team)]
	var file = FileAccess.open(team_file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary:
			if json.has("gold"):
				gold_label.text = "Oro: %s" % format_number(json["gold"])
			if json.has("players"):
				team = json.players
				if team.size() != 16:
					print("Warning: Team size is %d, resizing to 16" % team.size())
					var temp_team = []
					temp_team.resize(16)
					for i in min(16, team.size()):
						temp_team[i] = team[i] if team[i] != null else null
					team = temp_team
			if json.has("template"):
				load_template(json["template"])
				update_buy_options()
		file.close()
	else:
		show_message("Error: El archivo del equipo no existe. Crea el equipo en la escena Teams.")

func save_team():
	var file = FileAccess.open(team_file_path, FileAccess.WRITE)
	if file:
		var data = {
			"template": template_data.get("name", "unknown").to_lower(),
			"gold": int(gold_label.text.replace("Oro: ", "").replace(",", "")),
			"players": team
		}
		file.store_string(JSON.stringify(data, "\t"))
		file.close()

func update_team_list():
	item_list.clear()
	for i in range(team.size()):
		if team[i] != null:
			team[i].number = i + 1
			var text = "#%d - %s - %s" % [i + 1, team[i].name, team[i].position]
			item_list.add_item(text, null, true)
			if team[i].state == "herido":
				item_list.set_item_custom_fg_color(i, Color.RED)
			else:
				item_list.set_item_custom_fg_color(i, Color.WHITE)
		else:
			item_list.add_item("Vacío #%d" % [i + 1], null, true)
	item_list.deselect_all()

func load_template(template_name = "human"):
	var file_path = "res://Resources/TeamTemplates/%s_template.json" % template_name
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		template_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		template_data = {"name": "unknown", "positions": []}
	# Cargar nombres según la plantilla
	var names_file = "res://Resources/TeamTemplates/%s_names.json" % template_data["name"].to_lower()
	var names_file_access = FileAccess.open(names_file, FileAccess.READ)
	if names_file_access:
		var names = JSON.parse_string(names_file_access.get_as_text())
		if names is Dictionary and names.has("first_names") and names.has("titles"):
			first_names = names["first_names"]
			titles = names["titles"]
		names_file_access.close()
	print("Loaded template: ", template_data)

func update_buy_options():
	var selected_text = position_selector.get_item_text(position_selector.selected) if position_selector.get_item_count() > 0 else ""
	position_selector.clear()
	if template_data and template_data.has("positions"):
		for pos in template_data["positions"]:
			var pos_name = pos["name"]
			var current_count = get_position_count(pos_name)
			var max_count = pos["count"]
			var cost = pos["cost"]
			var display_text = "%s (Coste: %s) (Contratados %d/%d)" % [pos_name, format_number(cost), current_count, max_count]
			position_selector.add_item(display_text, position_selector.get_item_count())
			if display_text == selected_text:
				position_selector.select(position_selector.get_item_count() - 1)
	if position_selector.get_item_count() == 0:
		position_selector.add_item("No hay posiciones disponibles", 0)
		hire_player_button.disabled = true
	else:
		hire_player_button.disabled = false
		if selected_text != "" and position_selector.get_item_text(position_selector.selected) != selected_text:
			for i in range(position_selector.get_item_count()):
				if position_selector.get_item_text(i) == selected_text:
					position_selector.select(i)
					break

func _on_hire_player_button_pressed():
	if get_player_count() >= 16:
		show_message("¡Equipo completo! No puedes contratar más jugadores (máximo 16).")
		return
	var selected_pos = position_selector.get_item_text(position_selector.selected).split(" (Coste: ")[0]
	var cost = int(position_selector.get_item_text(position_selector.selected).split(" (Coste: ")[1].split(") (Contratados")[0].replace(",", ""))
	var gold = int(gold_label.text.replace("Oro: ", "").replace(",", ""))
	if gold < cost:
		show_message("No tienes suficiente oro.")
		return
	if not can_add_position(selected_pos):
		var max_count = 0
		for pos in template_data.get("positions", []):
			if pos["name"] == selected_pos:
				max_count = pos["count"]
				break
		show_message("Límite de %s alcanzado (%d/%d)." % [selected_pos, get_position_count(selected_pos), max_count])
		return
	var new_player = create_player(selected_pos)
	if new_player:
		var index = team.find(null)
		if index != -1:
			team[index] = new_player
			gold -= cost
			gold_label.text = "Oro: %s" % format_number(gold)
			update_team_list()
			save_team()
			update_buy_options()  # Actualizar el desplegable después de la contratación
			custom_name_input.text = ""
			show_message("Jugador %s contratado." % new_player.name)
		else:
			show_message("Error: No hay posiciones disponibles.")

func create_player(position_name):
	var custom_name = custom_name_input.text.strip_edges()
	var name = ""
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
		"position": position_name,
		"number": 0,
		"race": template_data["name"].to_lower(),
		"attributes": get_attributes_for_position(position_name),
		"skills": get_skills_for_position(position_name),
		"state": "healthy"
	}
	return player

func _on_delete_player_button_pressed():
	delete_mode = true
	delete_index = -1
	delete_player_button.text = "PULSA FUERA PARA CANCELAR"
	item_list.deselect_all()
	show_message("Selecciona un jugador para eliminar.")

func _on_back_button_pressed():
	save_team()
	var teams_scene = load("res://Scenes/Teams.tscn").instantiate()
	get_tree().root.add_child(teams_scene)
	get_tree().current_scene = teams_scene
	queue_free()

func _on_play_match_button_pressed():
	var player_count = get_player_count()
	if player_count < 11:
		show_message("Necesitas al menos 11 jugadores para jugar un partido. Tienes: %d" % player_count)
		return
	save_team()
	var match_scene = load("res://Scenes/Match.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()

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
		save_team()
		update_buy_options()  # Actualizar el desplegable después de eliminar
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
	var max_count = 0
	for pos in template_data.get("positions", []):
		if pos["name"] == position:
			max_count = pos["count"]
			break
	return count < max_count and get_player_count() < 16

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
	for pos in template_data.get("positions", []):
		if pos["name"] == position:
			return pos["attributes"].duplicate()
	return {}

func get_skills_for_position(position):
	for pos in template_data.get("positions", []):
		if pos["name"] == position:
			return pos["skills"].duplicate()
	return []

func format_number(number):
	return str(number).pad_decimals(0).insert(str(number).length() - 3, ",")
