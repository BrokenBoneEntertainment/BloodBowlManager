extends Control

var home_team_touchdowns = 0
var away_team_touchdowns = 0
var home_team_injuries = 0
var away_team_injuries = 0
var home_team = []
var away_team = []
var match_time = 0.0
var is_match_running = false
var current_phase = "first_half"  # "first_half", "halftime", "second_half"

@onready var score_label = $UIContainer/ScoreLabel
@onready var injury_label = $UIContainer/InjuryLabel
@onready var time_label = $UIContainer/TimeLabel
@onready var directo = $UIContainer/Directo
@onready var home_team_list = $UIContainer/HomeTeamList
@onready var away_team_list = $UIContainer/AwayTeamList
@onready var exit_match_button = $UIContainer/ExitMatchButton
@onready var home_team_label = $UIContainer/HomeTeamLabel
@onready var away_team_label = $UIContainer/AwayTeamLabel
@onready var details_popup = $UIContainer/DetailsPopup
@onready var details_label = $UIContainer/DetailsPopup/PopupContainer/DetailsLabel
@onready var timer = $MatchTimer

# Cargar JSON de jugadas
var play_data = {}
func _ready():
	var file = FileAccess.open("res://Resources/match_plays.json", FileAccess.READ)
	if file:
		play_data = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print("Error: No se pudo cargar match_plays.json")

	if not score_label or not injury_label or not time_label or not directo or not home_team_list or not away_team_list or not exit_match_button or not home_team_label or not away_team_label or not details_popup or not details_label or not timer:
		print("Error: UI nodes not found in Match.tscn")
		return
	
	load_teams()
	initialize_ui()
	start_match()
	exit_match_button.pressed.connect(_on_exit_match_button_pressed)
	timer.timeout.connect(_on_match_timer_timeout)
	home_team_list.item_clicked.connect(_on_team_list_item_clicked.bind("Home"))
	away_team_list.item_clicked.connect(_on_team_list_item_clicked.bind("Away"))
	
	if details_popup:
		details_popup.hide()
	else:
		print("Error: DetailsPopup no encontrado")

func sanitize_filename(input: String) -> String:
	if not input:
		return "default"
	var invalid_chars = ["%", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	var sanitized = input
	for char in invalid_chars:
		sanitized = sanitized.replace(char, "_")
	sanitized = sanitized.strip_edges().replace(" ", "_")
	return sanitized if sanitized else "default"

func load_teams():
	var file_path = "res://Resources/Teams/player_team_%s_%s.json" % [sanitize_filename(Global.current_user), sanitize_filename(Global.current_team)]
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Dictionary and json.has("players"):
			home_team = json.players.duplicate(true)  # Cargar el equipo real
			if home_team.size() != 16:
				print("Warning: Team size is %d, resizing to 16" % home_team.size())
				var temp_team = []
				temp_team.resize(16)
				for i in min(16, home_team.size()):
					temp_team[i] = home_team[i] if home_team[i] != null else null
				home_team = temp_team
			# Establecer los primeros 11 en "playing", mantener los nombres originales
			for i in min(11, home_team.size()):
				if home_team[i] != null:
					home_team[i].state = "playing"
				else:
					home_team[i] = create_player("Placeholder%d" % (i + 1), "Lineman")  # Usar "Placeholder" solo si es necesario
					home_team[i].state = "playing"
			for i in range(11, home_team.size()):
				if home_team[i] != null:
					home_team[i].state = "healthy"
			print("Debug: Loaded home_team: ", home_team)
		else:
			print("Error: Invalid JSON format in %s" % file_path)
			home_team.clear()
			home_team.resize(16)
			for i in range(11):
				home_team[i] = create_player("Filler%d" % (i + 1), "Lineman")
				home_team[i].state = "playing"
		file.close()
	else:
		print("Error: No team file found at %s" % file_path)
		home_team.clear()
		home_team.resize(16)
		for i in range(11):
			home_team[i] = create_player("Filler%d" % (i + 1), "Lineman")
			home_team[i].state = "playing"
	away_team = generate_opponent_team()

func generate_opponent_team() -> Array:
	var team = []
	team.resize(16)
	var positions = ["Lineman", "Thrower", "Catcher", "Blitzer", "Ogre", "Halfling"]
	var counts = {"Lineman": 0, "Thrower": 0, "Catcher": 0, "Blitzer": 0, "Ogre": 0, "Halfling": 0}
	for i in 16:
		var available_positions = positions.filter(func(p): return (
			counts[p] < 16 if p == "Lineman" else
			counts[p] < 2 if p == "Thrower" else
			counts[p] < 4 if p in ["Catcher", "Blitzer"] else
			counts[p] < 1 if p == "Ogre" else
			counts[p] < 3 if p == "Halfling" else false))
		if available_positions.is_empty():
			break
		var position = available_positions[randi() % available_positions.size()]
		counts[position] += 1
		team[i] = create_player("Rival%d" % (i + 1), position)
	# Establecer los primeros 11 en "playing"
	for i in min(11, team.size()):
		if team[i] != null:
			team[i].state = "playing"
	for i in range(11, team.size()):
		if team[i] != null:
			team[i].state = "healthy"
	return team

func create_player(name: String, position: String) -> Dictionary:
	var skills = []
	var attributes = {}
	match position:
		"Lineman":
			attributes = {"MA": 6, "ST": 3, "AG": 3, "PA": 4, "AV": 8}
			skills = []
		"Thrower":
			attributes = {"MA": 6, "ST": 3, "AG": 3, "PA": 2, "AV": 8}
			skills = ["Sure Hands", "Pass"]
		"Catcher":
			attributes = {"MA": 8, "ST": 2, "AG": 2, "PA": 4, "AV": 7}
			skills = ["Catch", "Dodge"]
		"Blitzer":
			attributes = {"MA": 7, "ST": 3, "AG": 3, "PA": 4, "AV": 8}
			skills = ["Block"]
		"Ogre":
			attributes = {"MA": 5, "ST": 5, "AG": 4, "PA": 5, "AV": 10}
			skills = ["Bone-head", "Mighty Blow", "Thick Skull", "Throw Team-mate"]
		"Halfling":
			attributes = {"MA": 5, "ST": 1, "AG": 3, "PA": 5, "AV": 6}
			skills = ["Dodge", "Right Stuff", "Stunty"]
	return {
		"name": name,
		"position": position,
		"number": 0,
		"race": "Human",
		"attributes": attributes,
		"skills": skills,
		"state": "healthy"
	}

func initialize_ui():
	home_team_label.text = "%s (Local)" % Global.current_team
	away_team_label.text = "Rival (Visitante)"
	score_label.text = "Touchdowns - Local: %d, Visitante: %d" % [home_team_touchdowns, away_team_touchdowns]
	injury_label.text = "Heridas - Local: %d, Visitante: %d" % [home_team_injuries, away_team_injuries]
	time_label.text = "Tiempo: %.1f s - %s" % [match_time, current_phase.capitalize().replace("_", " ")]
	update_team_lists()
	exit_match_button.disabled = true  # Botón inactivo al inicio

func update_team_lists():
	home_team_list.clear()
	away_team_list.clear()
	var home_index = 0
	for i in home_team.size():
		if home_team[i] != null:
			home_team[i].number = home_index + 1
			var text = "#%d - %s - %s" % [home_index + 1, home_team[i].name, home_team[i].position]
			home_team_list.add_item(text, null, true)
			match home_team[i].state:
				"herido":
					home_team_list.set_item_custom_fg_color(home_index, Color.RED)
				"playing":
					home_team_list.set_item_custom_fg_color(home_index, Color.GREEN)
				"healthy":
					home_team_list.set_item_custom_fg_color(home_index, Color.WHITE)
			home_index += 1
	var away_index = 0
	for i in away_team.size():
		if away_team[i] != null:
			away_team[i].number = away_index + 1
			var text = "#%d - %s - %s" % [away_index + 1, away_team[i].name, away_team[i].position]
			away_team_list.add_item(text, null, true)
			match away_team[i].state:
				"herido":
					away_team_list.set_item_custom_fg_color(away_index, Color.RED)
				"playing":
					away_team_list.set_item_custom_fg_color(away_index, Color.GREEN)
				"healthy":
					away_team_list.set_item_custom_fg_color(away_index, Color.WHITE)
			away_index += 1

func _on_team_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int, team_type: String):
	if mouse_button_index == MOUSE_BUTTON_LEFT and index >= 0:
		var team = home_team if team_type == "Home" else away_team
		var count = 0
		var target_index = -1
		for i in team.size():
			if team[i] != null:
				if count == index:
					target_index = i
					break
				count += 1
		if target_index != -1 and team[target_index] != null:
			if details_popup and details_label:
				details_label.text = "Nombre: %s\nPosición: %s\nHabilidades: %s\nAtributos: MA %d, ST %d, AG %d, PA %d, AV %d\nEstado: %s" % [
					team[target_index].name, team[target_index].position, ", ".join(team[target_index].skills if team[target_index].skills is Array else []),
					team[target_index].attributes.MA, team[target_index].attributes.ST, team[target_index].attributes.AG,
					team[target_index].attributes.PA, team[target_index].attributes.AV, team[target_index].state.capitalize()
				]
				details_popup.popup_centered()
			else:
				print("Error: DetailsPopup o DetailsLabel no encontrados")

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var home_rect = home_team_list.get_global_rect()
		var away_rect = away_team_list.get_global_rect()
		if not home_rect.has_point(event.global_position) and not away_rect.has_point(event.global_position):
			home_team_list.deselect_all()
			away_team_list.deselect_all()
			if details_popup:
				details_popup.hide()

func start_match():
	is_match_running = true
	match_time = 0.0
	current_phase = "first_half"
	timer.start(1.0)
	directo.append_text("[center]Partido en curso - %s[/center]\n" % current_phase.capitalize().replace("_", " "))
	time_label.text = "Tiempo: %.1f s - %s" % [match_time, current_phase.capitalize().replace("_", " ")]
	await get_tree().create_timer(10.0).timeout
	if is_match_running:
		timer.stop()
		current_phase = "halftime"
		directo.append_text("[center]Entretiempo - %s[/center]\n" % play_data["halftime_plays"][randi() % play_data["halftime_plays"].size()])
		time_label.text = "Tiempo: %.1f s - %s" % [match_time, current_phase.capitalize().replace("_", " ")]
		await get_tree().create_timer(5.0).timeout
		if is_match_running:
			current_phase = "second_half"
			directo.append_text("[center]Partido en curso - %s[/center]\n" % current_phase.capitalize().replace("_", " "))
			time_label.text = "Tiempo: %.1f s - %s" % [match_time, current_phase.capitalize().replace("_", " ")]
			timer.start(1.0)
			await get_tree().create_timer(10.0).timeout
			if is_match_running:
				end_match()

func _on_match_timer_timeout():
	match_time += 1.0
	time_label.text = "Tiempo: %.1f s - %s" % [match_time, current_phase.capitalize().replace("_", " ")]
	if current_phase in ["first_half", "second_half"]:
		process_play()

func process_play():
	if not is_match_running:
		return
	var play_type = ["pass", "touchdown", "injury", "dodge", "filler"][randi() % 5]
	var success = randf() < 0.5  # 50% de éxito
	var player_team = home_team if randf() < 0.5 else away_team
	var opponent_team = away_team if player_team == home_team else home_team
	var active_players = []
	for i in player_team.size():
		if player_team[i] != null and player_team[i].state == "playing":
			active_players.append(i)
	if active_players.size() == 0:
		directo.append_text("[center]No hay jugadores activos para esta jugada.[/center]\n")
		return

	var player_index = active_players[randi() % active_players.size()]
	var player = player_team[player_index]
	var play_key = "%s_%s" % [play_type, "success" if success else "failure"]
	var play_texts = play_data.get("plays", {}).get(play_key, {
		"pass_success": ["{player} lanza un pase exitoso."],
		"pass_failure": ["{player} falla el pase."],
		"touchdown_success": ["{player} anota un touchdown espectacular."],
		"touchdown_failure": ["{player} falla en su intento de touchdown."],
		"injury_success": ["{player} provoca una lesión grave."],
		"injury_failure": ["{player} intenta herir, pero falla."],
		"dodge_success": ["{player} esquiva con éxito."],
		"dodge_failure": ["{player} falla al intentar esquivar."],
		"filler": ["{player} realiza una jugada neutral."]
	}.get(play_key, ["{player} realiza una jugada genérica."]))
	var play_text = play_texts[randi() % play_texts.size()].format({"player": player.name})

	# Incluir el equipo al inicio del mensaje
	var team_name = home_team_label.text if player_team == home_team else away_team_label.text
	play_text = "%s: %s" % [team_name, play_text]

	# Aplicar colores según el tipo de jugada
	if play_key == "touchdown_success":
		directo.push_color(Color.GREEN)
		directo.append_text("[center]%s[/center]\n" % play_text)
		directo.pop()
		if player_team == home_team:
			home_team_touchdowns += 1
		else:
			away_team_touchdowns += 1
	elif play_key == "injury_success":
		directo.push_color(Color.RED)
		directo.append_text("[center]%s[/center]\n" % play_text)
		directo.pop()
		var injured_team = opponent_team
		var active_opponents = []
		for i in injured_team.size():
			if injured_team[i] != null and injured_team[i].state == "playing":
				active_opponents.append(i)
		if active_opponents.size() > 0:
			var injured_index = active_opponents[randi() % active_opponents.size()]
			var injured_player = injured_team[injured_index]
			injured_team[injured_index].state = "herido"
			if player_team == home_team:
				home_team_injuries += 1
			else:
				away_team_injuries += 1
			# Jugada de sustitución como adicional
			for i in range(injured_index + 1, injured_team.size()):
				if injured_team[i] != null and injured_team[i].state == "healthy":
					var substitute = injured_team[i]
					injured_team[injured_index] = substitute.duplicate()
					injured_team[injured_index].state = "playing"
					injured_team[i] = null
					directo.append_text("[center]Sustitución: Jugador %s herido, sustituido por %s.[/center]\n" % [injured_player.name, substitute.name])
					break
	elif play_key in ["touchdown_failure", "injury_failure"]:
		directo.push_color(Color.BLUE)
		directo.append_text("[center]%s[/center]\n" % play_text)
		directo.pop()
	else:  # pass, dodge, filler
		directo.append_text("[center]%s[/center]\n" % play_text)

	score_label.text = "Touchdowns - Local: %d, Visitante: %d" % [home_team_touchdowns, away_team_touchdowns]
	injury_label.text = "Heridas - Local: %d, Visitante: %d" % [home_team_injuries, away_team_injuries]
	update_team_lists()

func end_match():
	is_match_running = false
	timer.stop()
	exit_match_button.disabled = false  # Activar botón al finalizar
	directo.append_text("[center]Fin del partido: Local %d - %d Visitante[/center]\n" % [home_team_touchdowns, away_team_touchdowns])

func _on_exit_match_button_pressed():
	if not exit_match_button.disabled:
		is_match_running = false
		timer.stop()
		var team_management_scene = load("res://Scenes/TeamManagement.tscn").instantiate()
		get_tree().root.add_child(team_management_scene)
		get_tree().current_scene = team_management_scene
		queue_free()
