extends Control

# Match data
var player_team = []
var opponent_team = []
var first_names = []
var titles = []
var match_plays = {}
var match_ended = false
var player_score = 0
var opponent_score = 0
var player_injuries = 0
var opponent_injuries = 0
var time = 0
var is_first_half = true

# UI node references
@onready var score_label = $UIContainer/ScoreLabel
@onready var injury_label = $UIContainer/InjuryLabel
@onready var time_label = $UIContainer/TimeLabel
@onready var directo = $UIContainer/Directo
@onready var home_team_list = $UIContainer/HomeTeamList
@onready var away_team_list = $UIContainer/AwayTeamList
@onready var exit_match_button = $UIContainer/ExitMatchButton

# Called when the node is ready
func _ready():
	var file = FileAccess.open("res://Resources/player_names.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		first_names = json["first_names"]
		titles = json["titles"]
		file.close()
	else:
		directo.append_text("Error: No se pudo cargar player_names.json\n")
	
	file = FileAccess.open("res://Resources/match_plays.json", FileAccess.READ)
	if file:
		match_plays = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		directo.append_text("Error: No se pudo cargar match_plays.json\n")
	
	if not score_label or not injury_label or not time_label or not directo or not home_team_list or not away_team_list or not exit_match_button:
		directo.append_text("Error: UI nodes not found\n")
		return
	
	score_label.text = "%s 0 - 0 Rival Orkos" % Global.current_team
	injury_label.text = "Heridas: Casa 0, Visitante 0"
	time_label.text = "Tiempo: 0s (Primera parte)"
	exit_match_button.text = "Volver"
	exit_match_button.hide()
	exit_match_button.disabled = true  # Disable button at start
	
	load_teams()
	update_team_lists()
	
	# Connect signals programmatically
	exit_match_button.pressed.connect(_on_exit_match_button_pressed)
	
	# Start automatic match
	start_match()

# Loads both teams
func load_teams():
	var file = FileAccess.open("res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, Global.current_team], FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		player_team = json.get("players", [])
		file.close()
	
	file = FileAccess.open("res://Resources/opponent_teams.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		if json is Array and json.size() > 0:
			# If json is an array of player arrays, select one randomly
			if json[0] is Array:
				opponent_team = json[randi() % json.size()]
			# If json is an array of dictionaries with "players" key
			elif json[0] is Dictionary and json[0].has("players"):
				opponent_team = json[randi() % json.size()]["players"]
			else:
				print("Error: Invalid opponent_teams.json structure: ", json)
				opponent_team = generate_opponent_team()
		else:
			print("Error: opponent_teams.json is empty or not an array: ", json)
			opponent_team = generate_opponent_team()
		file.close()
	else:
		print("Warning: opponent_teams.json not found, generating opponent team")
		opponent_team = generate_opponent_team()
	
	# Ensure opponent_team is an array of 24 elements
	if opponent_team.size() != 24:
		print("Warning: opponent_team size is %d, resizing to 24" % opponent_team.size())
		opponent_team.resize(24)
		for i in range(24):
			opponent_team[i] = opponent_team[i] if i < opponent_team.size() and opponent_team[i] != null else null


# Generates a random opponent team
func generate_opponent_team():
	var team = []
	team.resize(24)
	for i in range(24):
		team[i] = null
	var positions = ["Fighter", "Defender", "Thrower", "Runner"]
	for i in range(16):  # Generate 16 players
		var pos = randi() % 4
		var position = positions[pos]
		var name = first_names[randi() % first_names.size()] + " " + titles[randi() % titles.size()]
		team[i] = {
			"name": name,
			"position": position,
			"number": i + 1,
			"race": "Orc",
			"stats": get_stats_for_position(position),
			"state": "playing" if i < 11 else "healthy"
		}
	return team

# Starts the match with automatic plays
func start_match():
	while not match_ended:
		for i in range(10):  # First half: 10 plays, 1 per second
			if match_ended:
				break
			perform_play()
			update_ui()
			await get_tree().create_timer(1.0).timeout
			time += 1
		if not match_ended:
			is_first_half = false
			time_label.text = "Tiempo: Entretiempo"
			var halftime_play = match_plays["halftime_plays"][randi() % match_plays["halftime_plays"].size()]
			directo.append_text("[b]%s[/b]\n" % halftime_play)
			await get_tree().create_timer(5.0).timeout
			time = 0
			for i in range(10):  # Second half: 10 plays, 1 per second
				if match_ended:
					break
				perform_play()
				update_ui()
				await get_tree().create_timer(1.0).timeout
				time += 1
		match_ended = true
	
	exit_match_button.disabled = false
	exit_match_button.show()
	directo.append_text("\n[b]¡Partido terminado! Resultado final: %s %d - %d Rival Orkos[/b]\n" % [Global.current_team, player_score, opponent_score])
	directo.scroll_to_line(directo.get_line_count() - 1)
	save_player_team()

# Performs a single play
func perform_play():
	var play_types = ["pass_success", "pass_failure", "touchdown_success", "touchdown_failure", "injury_success", "injury_failure", "dodge_success", "dodge_failure", "filler"]
	var play_type = play_types[randi() % play_types.size()]
	var play = match_plays["plays"][play_type][randi() % match_plays["plays"][play_type].size()]
	var is_player_team = randf() > 0.5
	var team_name = Global.current_team if is_player_team else "Rival Orkos"
	var team = player_team if is_player_team else opponent_team
	var other_team = opponent_team if is_player_team else player_team
	var player = get_random_player(team, "playing")
	var play_text = "[%s] %s" % [team_name, play.format({"player": player.name})]
	var color = Color.WHITE
	
	if play_type == "touchdown_success":
		color = Color.GREEN
		if is_player_team:
			player_score += 1
		else:
			opponent_score += 1
	elif play_type == "injury_success":
		color = Color.RED
		var injured_player = get_random_player(other_team, "playing")
		var sub_player = get_random_player(other_team, "healthy")
		injured_player.state = "herido"
		if is_player_team:
			player_injuries += 1
		else:
			opponent_injuries += 1
		play_text += "\n[color=red][%s] %s está herido![/color]" % [team_name if not is_player_team else "Rival Orkos", injured_player.name]
		if sub_player != null:
			sub_player.state = "playing"
			play_text += "\n[%s] %s entra como sustituto." % [team_name if not is_player_team else "Rival Orkos", sub_player.name]
	elif play_type in ["touchdown_failure", "injury_failure"]:
		color = Color.BLUE
	
	directo.append_text("[color=%s]%s[/color]\n" % [color.to_html(), play_text])
	directo.scroll_to_line(directo.get_line_count() - 1)
	
	var active_players = get_active_players(player_team)
	var active_opponents = get_active_players(opponent_team)
	if active_players < 7 or active_opponents < 7:
		match_ended = true

# Updates UI elements
func update_ui():
	score_label.text = "%s %d - %d Rival Orkos" % [Global.current_team, player_score, opponent_score]
	injury_label.text = "Heridas: Casa %d, Visitante %d" % [player_injuries, opponent_injuries]
	time_label.text = "Tiempo: %ds (%s)" % [time, "Primera parte" if is_first_half else "Segunda parte"]
	update_team_lists()

# Updates team lists in UI
func update_team_lists():
	home_team_list.clear()
	away_team_list.clear()
	for i in range(player_team.size()):
		if player_team[i] != null:
			var text = "#%d - %s - %s - %s - %s" % [
				player_team[i].number, player_team[i].name, player_team[i].position,
				player_team[i].race, player_team[i].state.capitalize()
			]
			home_team_list.add_item(text)
			if player_team[i].state == "playing":
				home_team_list.set_item_custom_fg_color(i, Color.GREEN)
			elif player_team[i].state == "herido":
				home_team_list.set_item_custom_fg_color(i, Color.RED)
			else:
				home_team_list.set_item_custom_fg_color(i, Color.WHITE)
	for i in range(opponent_team.size()):
		if opponent_team[i] != null:
			var text = "#%d - %s - %s - %s - %s" % [
				opponent_team[i].number, opponent_team[i].name, opponent_team[i].position,
				opponent_team[i].race, opponent_team[i].state.capitalize()
			]
			away_team_list.add_item(text)
			if opponent_team[i].state == "playing":
				away_team_list.set_item_custom_fg_color(i, Color.GREEN)
			elif opponent_team[i].state == "herido":
				away_team_list.set_item_custom_fg_color(i, Color.RED)
			else:
				away_team_list.set_item_custom_fg_color(i, Color.WHITE)

# Handles exit match button press
func _on_exit_match_button_pressed():
	save_player_team()
	var team_management_scene = load("res://Scenes/TeamManagement.tscn").instantiate()
	get_tree().root.add_child(team_management_scene)
	get_tree().current_scene = team_management_scene
	queue_free()

# Saves the player's team
func save_player_team():
	var dir = DirAccess.open("res://Resources/")
	if not dir.dir_exists("Teams"):
		dir.make_dir("Teams")
	var file = FileAccess.open("res://Resources/Teams/player_team_%s_%s.json" % [Global.current_user, Global.current_team], FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players": player_team}, "\t"))
		file.close()

# Returns a random player with the given state
func get_random_player(team, state: String):
	if not team is Array:
		print("Error: Team is not an array, type: ", typeof(team), " value: ", team)
		team = team.values() if team is Dictionary else []  # Convert to array if dictionary
	var valid_players = []
	for player in team:
		if player != null and player.state == state:
			valid_players.append(player)
	if valid_players.is_empty():
		for player in team:
			if player != null and player.state != "herido":
				return player
		return {"name": "Unknown", "state": "healthy"}  # Fallback if no valid players
	return valid_players[randi() % valid_players.size()]

# Returns the number of active (non-injured) players
func get_active_players(team: Array):
	var count = 0
	for player in team:
		if player != null and player.state != "herido":
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
