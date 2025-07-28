extends Control

var home_team_injuries = 0
var away_team_injuries = 0
var home_team = []
var away_team = []
var match_time = 0.0
var is_match_running = false

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

func _ready():
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
			home_team = json.players
			if home_team.size() != 16:
				print("Warning: Home team size is %d, resizing to 16" % home_team.size())
				home_team.resize(16)
				for i in range(16):
					home_team[i] = home_team[i] if i < home_team.size() and home_team[i] != null else null
		else:
			print("Error: Invalid JSON format in %s" % file_path)
			home_team = []
			home_team.resize(16)
			for i in range(16):
				home_team[i] = null
		file.close()
	else:
		print("Error: No team file found at %s" % file_path)
		home_team = []
		home_team.resize(16)
		for i in range(16):
			home_team[i] = null
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
	score_label.text = "Local: %d - Visitante: %d" % [home_team_injuries, away_team_injuries]
	injury_label.text = "Heridas - Local: %d, Visitante: %d" % [home_team_injuries, away_team_injuries]
	time_label.text = "Tiempo: %.1f s" % match_time
	directo.clear()
	directo.append_text("[center]Partido en curso[/center]")
	update_team_lists()

func update_team_lists():
	home_team_list.clear()
	away_team_list.clear()
	for i in home_team.size():
		if home_team[i] != null:
			home_team[i].number = i + 1
			var text = "#%d - %s - %s" % [i + 1, home_team[i].name, home_team[i].position]
			home_team_list.add_item(text, null, true)
			match home_team[i].state:
				"herido":
					home_team_list.set_item_custom_fg_color(i, Color.RED)
				"playing":
					home_team_list.set_item_custom_fg_color(i, Color.GREEN)
				_:
					home_team_list.set_item_custom_fg_color(i, Color.WHITE)
		else:
			home_team_list.add_item("Vacío #%d" % [i + 1], null, true)
	for i in away_team.size():
		if away_team[i] != null:
			away_team[i].number = i + 1
			var text = "#%d - %s - %s" % [i + 1, away_team[i].name, away_team[i].position]
			away_team_list.add_item(text, null, true)
			match away_team[i].state:
				"herido":
					away_team_list.set_item_custom_fg_color(i, Color.RED)
				"playing":
					away_team_list.set_item_custom_fg_color(i, Color.GREEN)
				_:
					away_team_list.set_item_custom_fg_color(i, Color.WHITE)
		else:
			away_team_list.add_item("Vacío #%d" % [i + 1], null, true)

func _on_team_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int, team_type: String):
	if mouse_button_index == MOUSE_BUTTON_LEFT and index >= 0 and index < (home_team.size() if team_type == "Home" else away_team.size()):
		var team = home_team if team_type == "Home" else away_team
		if team[index] != null:
			if details_popup and details_label:
				details_label.text = "Nombre: %s\nPosición: %s\nHabilidades: %s\nAtributos: MA %d, ST %d, AG %d+, PA %d+, AV %d+\nEstado: %s" % [
					team[index].name, team[index].position, ", ".join(team[index].skills),
					team[index].attributes.MA, team[index].attributes.ST, team[index].attributes.AG,
					team[index].attributes.PA, team[index].attributes.AV, team[index].state.capitalize()
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
	timer.start(1.0)
	directo.clear()
	directo.append_text("[center]Partido en curso[/center]")
	await get_tree().create_timer(10.0).timeout
	if is_match_running:
		timer.stop()
		directo.clear()
		directo.append_text("[center]Pausa (10s)[/center]")
		await get_tree().create_timer(5.0).timeout
		if is_match_running:
			directo.clear()
			directo.append_text("[center]Partido en curso[/center]")
			timer.start(1.0)
			await get_tree().create_timer(10.0).timeout
			if is_match_running:
				end_match()

func _on_match_timer_timeout():
	match_time += 1.0
	time_label.text = "Tiempo: %.1f s" % match_time
	process_play()

func process_play():
	if not is_match_running:
		return
	var injury_chance = randf()
	if injury_chance < 0.1:
		var injured_team = "home" if randf() < 0.5 else "away"
		var team_to_injure = home_team if injured_team == "home" else away_team
		var active_players = []
		for i in team_to_injure.size():
			if team_to_injure[i] != null and team_to_injure[i].state == "playing":
				active_players.append(i)
		if active_players.size() > 0:
			var injured_index = active_players[randi() % active_players.size()]
			team_to_injure[injured_index].state = "herido"
			if injured_team == "home":
				away_team_injuries += 1
			else:
				home_team_injuries += 1
			injury_label.text = "Heridas - Local: %d, Visitante: %d" % [home_team_injuries, away_team_injuries]
			score_label.text = "Local: %d - Visitante: %d" % [home_team_injuries, away_team_injuries]
			directo.clear()
			directo.append_text("[center]¡Herida en el equipo %s! Jugador: %s[/center]" % [injured_team, team_to_injure[injured_index].name])
			update_team_lists()

func end_match():
	is_match_running = false
	timer.stop()
	directo.clear()
	directo.append_text("[center]Fin del partido: Local %d - Visitante %d[/center]" % [home_team_injuries, away_team_injuries])

func _on_exit_match_button_pressed():
	var main_scene = load("res://Scenes/Main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	queue_free()
