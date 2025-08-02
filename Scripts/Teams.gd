extends Control

var teams = []

@onready var title_label = $UIContainer/TitleLabel
@onready var team_list = $UIContainer/TeamList
@onready var create_team_button = $UIContainer/CreateTeamButton
@onready var message_label = $UIContainer/MessageLabel
@onready var back_button = $UIContainer/BackButton
@onready var create_team_popup = $UIContainer/CreateTeamPopup
@onready var team_name_input = $UIContainer/CreateTeamPopup/PopupContent/TeamNameInput
@onready var template_selector = $UIContainer/CreateTeamPopup/PopupContent/TemplateSelector
@onready var confirm_create_button = $UIContainer/CreateTeamPopup/PopupContent/ConfirmCreateButton
@onready var cancel_create_button = $UIContainer/CreateTeamPopup/PopupContent/CancelCreateButton
@onready var popup_message_label = $UIContainer/CreateTeamPopup/PopupContent/PopupMessageLabel
@onready var confirm_delete_team_popup = $UIContainer/ConfirmDeleteTeamPopup
@onready var delete_team_popup_label = $UIContainer/ConfirmDeleteTeamPopup/PopupContainer/DeleteTeamPopupLabel
@onready var confirm_delete_team_button = $UIContainer/ConfirmDeleteTeamPopup/PopupContainer/ButtonContainer/ConfirmDeleteTeamButton
@onready var cancel_delete_team_button = $UIContainer/ConfirmDeleteTeamPopup/PopupContainer/ButtonContainer/CancelDeleteTeamButton

func _ready():
	if not Global.current_user:
		Global.current_user = "default_user"
	Global.current_user = Global.sanitize_filename(Global.current_user)
	title_label.text = "Tus Equipos"
	create_team_button.text = "Crear Equipo"
	back_button.text = "Volver"
	team_name_input.placeholder_text = "Nombre del equipo"
	confirm_create_button.text = "Confirmar"
	cancel_create_button.text = "Cancelar"
	confirm_delete_team_button.text = "Confirmar"
	cancel_delete_team_button.text = "Cancelar"
	load_teams()
	update_team_list()
	create_team_popup.hide()
	confirm_delete_team_popup.hide()
	create_team_button.pressed.connect(_on_create_team_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	confirm_create_button.pressed.connect(_on_confirm_create_button_pressed)
	cancel_create_button.pressed.connect(_on_cancel_create_button_pressed)
	confirm_delete_team_button.pressed.connect(_on_confirm_delete_team_button_pressed)
	cancel_delete_team_button.pressed.connect(_on_cancel_delete_team_button_pressed)
	# Cargar plantillas una sola vez al iniciar
	load_templates()

func load_teams():
	var user_dir = "res://Resources/UserTeams/%s/" % Global.current_user
	var file_path = "%steams_%s.json" % [user_dir, Global.current_user]
	var dir = DirAccess.open("res://Resources/UserTeams/")
	if not dir:
		DirAccess.make_dir_absolute("res://Resources/UserTeams/")
	if not DirAccess.dir_exists_absolute(user_dir):
		DirAccess.make_dir_absolute(user_dir)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary and json.has("teams"):
			teams = json.teams
		file.close()
	else:
		teams = []
		save_teams()
	# Validar existencia de archivos de equipo
	var valid_teams = []
	for team in teams.duplicate():
		var team_file = team.file
		var full_path = "%s%s" % [user_dir, team_file]
		if not DirAccess.dir_exists_absolute(user_dir) or not FileAccess.file_exists(full_path):
			print("Archivo no encontrado para equipo %s, eliminando de la lista." % team.name)
		else:
			valid_teams.append(team)
	teams = valid_teams
	save_teams()

func save_teams():
	var user_dir = "res://Resources/UserTeams/%s/" % Global.current_user
	var dir = DirAccess.open("res://Resources/UserTeams/")
	if not dir:
		DirAccess.make_dir_absolute("res://Resources/UserTeams/")
	if not DirAccess.dir_exists_absolute(user_dir):
		DirAccess.make_dir_absolute(user_dir)
	var file_path = "%steams_%s.json" % [user_dir, Global.current_user]
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"teams": teams}, "\t"))
		file.close()

func update_team_list():
	for child in team_list.get_children():
		child.queue_free()
	for i in teams.size():
		var container = HBoxContainer.new()
		container.name = "Team%dContainer" % (i + 1)
		var name_label = Label.new()
		name_label.text = teams[i].name
		var manage_button = Button.new()
		manage_button.text = "Administrar"
		manage_button.pressed.connect(_on_manage_button_pressed.bind(i))
		var delete_button = Button.new()
		delete_button.text = "Eliminar"
		delete_button.pressed.connect(_on_delete_button_pressed.bind(i))
		container.add_child(name_label)
		container.add_child(manage_button)
		container.add_child(delete_button)
		team_list.add_child(container)
	create_team_button.disabled = teams.size() >= Global.MAX_TEAMS
	if teams.size() >= Global.MAX_TEAMS:
		show_message("Límite de %d equipos alcanzado." % Global.MAX_TEAMS)

func load_templates():
	template_selector.clear()  # Limpiar el OptionButton antes de cargar
	var dir = DirAccess.open("res://Resources/TeamTemplates/")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var loaded_templates = {}  # Evitar duplicados
		while file_name != "":
			if file_name.ends_with(".json"):
				var file = FileAccess.open("res://Resources/TeamTemplates/" + file_name, FileAccess.READ)
				if file:
					var json = JSON.parse_string(file.get_as_text())
					if json is Dictionary and json.has("name") and json.has("active") and json["active"]:
						var template_name = json["name"].to_lower()
						if not loaded_templates.has(template_name):
							loaded_templates[template_name] = true
							template_selector.add_item(json["name"], template_selector.get_item_count())
					file.close()
			file_name = dir.get_next()
		dir.list_dir_end()
	if template_selector.get_item_count() == 0:
		template_selector.add_item("No hay plantillas activas", 0)
		template_selector.select(0)
		confirm_create_button.disabled = true
	else:
		template_selector.select(0)
		confirm_create_button.disabled = false
	print("Loaded templates count: ", template_selector.get_item_count())  # Depuración

func _on_create_team_button_pressed():
	if teams.size() >= Global.MAX_TEAMS:
		show_message("Límite de %d equipos alcanzado." % Global.MAX_TEAMS)
		return
	team_name_input.text = ""
	popup_message_label.text = ""
	create_team_popup.popup_centered()

func _on_confirm_create_button_pressed():
	var team_name = team_name_input.text.strip_edges()
	if team_name == "":
		show_popup_message("Introduce un nombre para el equipo.")
		return
	# Validar unicidad global
	var global_team_names = load_global_team_names()
	print("Checking global team names: ", global_team_names)
	if global_team_names.has(team_name):
		show_popup_message("El nombre %s ya está en uso por otro equipo en la aplicación." % team_name)
		return
	var sanitized_team_name = Global.sanitize_filename(team_name)
	var team_file = "player_team_%s_%s.json" % [Global.current_user, sanitized_team_name]
	var user_dir = "res://Resources/UserTeams/%s/" % Global.current_user
	var file_path = "%s%s" % [user_dir, team_file]
	var dir = DirAccess.open(user_dir)
	if not dir:
		DirAccess.make_dir_absolute(user_dir)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var template_name = template_selector.get_item_text(template_selector.selected).to_lower()
		print("Selected template: ", template_name)  # Depuración
		# Definir el diccionario con orden explícito
		var initial_team = {}
		initial_team["template"] = template_name
		initial_team["gold"] = 1000000
		initial_team["players"] = []
		initial_team.players.resize(16)
		for i in range(16):
			initial_team.players[i] = null
		var json_string = JSON.stringify(initial_team, "\t")
		print("Writing JSON: ", json_string)  # Depuración
		file.store_string(json_string)
		file.close()
	else:
		show_popup_message("Error al crear el archivo del equipo.")
		return
	teams.append({"name": team_name, "file": team_file})
	save_teams()
	global_team_names.append(team_name)
	var success = save_global_team_names(global_team_names)
	if not success:
		show_popup_message("Error al guardar el nombre global del equipo.")
		return
	show_popup_message("Equipo %s creado." % team_name)
	await get_tree().create_timer(2.0).timeout
	create_team_popup.hide()
	update_team_list()

func _on_cancel_create_button_pressed():
	create_team_popup.hide()
	show_popup_message("Creación de equipo cancelada.")

func _on_manage_button_pressed(team_index: int):
	Global.current_team = teams[team_index].name
	var team_management_scene = load("res://Scenes/TeamManagement.tscn").instantiate()
	get_tree().root.add_child(team_management_scene)
	get_tree().current_scene = team_management_scene
	queue_free()

func _on_delete_button_pressed(team_index: int):
	if team_index >= 0 and team_index < teams.size():
		delete_team_popup_label.text = "¿Eliminar el equipo %s?" % [teams[team_index].name]
		confirm_delete_team_popup.popup_centered()
		confirm_delete_team_popup.set_meta("team_index", team_index)
	else:
		show_message("Error: Equipo no válido")

func _on_confirm_delete_team_button_pressed():
	var team_index = confirm_delete_team_popup.get_meta("team_index", -1)
	if team_index >= 0 and team_index < teams.size():
		var team_name = teams[team_index].name
		var team_file = teams[team_index].file
		var user_dir = "res://Resources/UserTeams/%s/" % Global.current_user
		var full_path = "%s%s" % [user_dir, team_file]
		var dir = DirAccess.open(user_dir)
		if dir:
			var files = dir.get_files()
			for file in files:
				if file.begins_with("player_team_%s_%s" % [Global.current_user, Global.sanitize_filename(team_name)]):
					var file_path = "%s%s" % [user_dir, file]
					var error = dir.remove(file_path)
					if error == OK:
						print("Archivo %s eliminado correctamente." % file_path)
					else:
						print("Error al eliminar el archivo %s: %s" % [file_path, error_string(error)])
			teams.remove_at(team_index)
			save_teams()
			var global_team_names = load_global_team_names()
			global_team_names.erase(team_name)
			var success = save_global_team_names(global_team_names)
			if not success:
				show_popup_message("Error al actualizar los nombres globales.")
				return
			update_team_list()
			show_popup_message("Equipo %s eliminado." % [team_name])
	confirm_delete_team_popup.hide()
	confirm_delete_team_popup.remove_meta("team_index")

func _on_cancel_delete_team_button_pressed():
	confirm_delete_team_popup.hide()
	confirm_delete_team_popup.remove_meta("team_index")
	show_popup_message("Eliminación de equipo cancelada.")

func _on_back_button_pressed():
	var main_scene = load("res://Scenes/Main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	queue_free()

func show_message(message: String):
	message_label.text = message
	await get_tree().create_timer(2.0).timeout
	message_label.text = ""

func show_popup_message(message: String):
	popup_message_label.text = message
	await get_tree().create_timer(2.0).timeout
	popup_message_label.text = ""

func load_global_team_names():
	var file_path = "res://Resources/team_names.json"
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary and json.has("team_names"):
			var names = json.team_names
			print("Loaded global team names: ", names)
			return names
		file.close()
	print("No team_names.json found or invalid, returning empty list")
	return []

func save_global_team_names(team_names):
	var file_path = "res://Resources/team_names.json"
	var dir = DirAccess.open("res://Resources/")
	if not dir:
		var error = DirAccess.make_dir_absolute("res://Resources/")
		if error != OK:
			print("Error creating Resources dir: ", error_string(error))
			return false
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"team_names": team_names}, "\t"))
		file.close()
		print("Saved global team names: ", team_names)
		return true
	print("Error opening team_names.json for writing")
	return false
