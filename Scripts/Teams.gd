extends Control

var teams = []

@onready var title_label = $UIContainer/TitleLabel
@onready var team_list = $UIContainer/TeamList
@onready var create_team_button = $UIContainer/CreateTeamButton
@onready var message_label = $UIContainer/MessageLabel
@onready var back_button = $UIContainer/BackButton
@onready var create_team_popup = $UIContainer/CreateTeamPopup
@onready var team_name_input = $UIContainer/CreateTeamPopup/PopupContent/TeamNameInput
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

func load_teams():
	var file_path = "res://Resources/Teams/teams_%s.json" % Global.current_user
	var dir = DirAccess.open("res://Resources/Teams/")
	if not dir:
		DirAccess.make_dir_absolute("res://Resources/Teams/")
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
		var full_path = "res://Resources/Teams/%s" % team_file
		if not dir.file_exists(full_path):
			print("Archivo no encontrado para equipo %s, eliminando de la lista." % team.name)
		else:
			valid_teams.append(team)
	teams = valid_teams
	save_teams()

func save_teams():
	var dir = DirAccess.open("res://Resources/")
	if not dir.dir_exists("Teams"):
		dir.make_dir("Teams")
	var file_path = "res://Resources/Teams/teams_%s.json" % Global.current_user
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
	if teams.any(func(t): return t.name == team_name):
		show_popup_message("El nombre del equipo ya existe.")
		return
	var sanitized_team_name = Global.sanitize_filename(team_name)
	var team_file = "player_team_%s_%s.json" % [Global.current_user, sanitized_team_name]
	# Crear archivo inicial con 16 nulls
	var file_path = "res://Resources/Teams/%s" % team_file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var initial_team = []
		initial_team.resize(16)  # Usar 16 slots en lugar de 24 para consistencia con TeamManagement
		for i in range(16):
			initial_team[i] = null
		file.store_string(JSON.stringify({"players": initial_team}, "\t"))
		file.close()
	else:
		show_popup_message("Error al crear el archivo del equipo.")
		return
	teams.append({"name": team_name, "file": team_file})
	save_teams()
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
		var full_path = "res://Resources/Teams/%s" % team_file
		var dir = DirAccess.open("res://Resources/Teams/")
		if dir:
			# Buscar y eliminar cualquier archivo con el mismo nombre base
			var files = dir.get_files()
			for file in files:
				if file.begins_with("player_team_%s_%s" % [Global.current_user, Global.sanitize_filename(team_name)]):
					var file_path = "res://Resources/Teams/%s" % file
					var error = dir.remove(file_path)
					if error == OK:
						print("Archivo %s eliminado correctamente." % file_path)
					else:
						print("Error al eliminar el archivo %s: %s" % [file_path, error_string(error)])
			teams.remove_at(team_index)
			save_teams()
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
