extends Control

var home_team = []  # Equipo del jugador
var away_team = []  # Equipo rival
var plays = []  # Registro de jugadas (solo en memoria)
var score = [0, 0]  # [home, away]
var injuries = [0, 0]  # [home, away] para heridas provocadas
var play_templates = {}  # Plantillas de jugadas desde JSON
var current_time = 0  # Tiempo de la parte actual (0-10 segundos)
var is_halftime = false  # Indicador de entretiempo

# Referencias a nodos de la UI
@onready var score_label = $UIContainer/ScoreLabel
@onready var injury_label = $UIContainer/InjuryLabel
@onready var time_label = $UIContainer/TimeLabel
@onready var directo_label = $UIContainer/Directo
@onready var home_team_list = $UIContainer/HomeTeamList
@onready var away_team_list = $UIContainer/AwayTeamList
@onready var exit_match_button = $UIContainer/ExitMatchButton

# Inicializa la escena
func _ready():
	if not score_label or not injury_label or not time_label or not directo_label or not home_team_list or not away_team_list or not exit_match_button:
		print("Error: Uno o más nodos UI no encontrados")
		return
	# Habilitar BBCode en Directo
	directo_label.bbcode_enabled = true
	# Desactivar el botón de salir al inicio
	exit_match_button.disabled = true
	# Cargar plantillas de jugadas
	load_play_templates()
	# Cargar equipos desde JSON
	load_teams()
	print("Nodos UI encontrados. Equipos - Jugador: ", home_team.size(), " Rival: ", away_team.size())
	update_team_lists()
	update_labels()
	# Iniciar simulación de jugadas
	start_match_simulation()

# Carga las plantillas de jugadas desde match_plays.json
func load_play_templates():
	var file = FileAccess.open("res://Resources/match_plays.json", FileAccess.READ)
	if file:
		play_templates = JSON.parse_string(file.get_as_text())
		file.close()
	else:
		print("Error: No se pudo cargar match_plays.json")

# Carga los equipos desde JSON
func load_teams():
	# Cargar equipo del jugador
	var player_file = FileAccess.open("res://Resources/player_team.json", FileAccess.READ)
	if player_file:
		var json = JSON.parse_string(player_file.get_as_text())
		home_team = json["players"]
		# Asegurar que los primeros 11 jugadores no heridos estén en "jugando"
		var active_count = 0
		for i in range(home_team.size()):
			if home_team[i] != null and active_count < 11 and home_team[i].state != "herido":
				home_team[i].state = "jugando"
				active_count += 1
			elif home_team[i] != null and home_team[i].state != "herido":
				home_team[i].state = "sano"
		player_file.close()
	else:
		print("Error: No se pudo cargar player_team.json")
		home_team.resize(24)
		for i in range(24):
			home_team[i] = null
	
	# Cargar equipo rival fijo (16 jugadores)
	var opponent_file = FileAccess.open("res://Resources/opponent_teams.json", FileAccess.READ)
	if opponent_file:
		var json = JSON.parse_string(opponent_file.get_as_text())
		away_team = json["opponents"]
		if away_team.size() != 16:
			print("Error: opponent_teams.json debe contener exactamente 16 jugadores")
		else:
			# Asignar estados: primeros 11 "jugando", últimos 5 "sano"
			for i in range(away_team.size()):
				away_team[i].state = "jugando" if i < 11 else "sano"
		opponent_file.close()
	else:
		print("Error: No se pudo cargar opponent_teams.json")
		away_team = []

# Actualiza las listas de equipos con colores según estado
func update_team_lists():
	if home_team_list:
		home_team_list.clear()
		for i in range(home_team.size()):
			if home_team[i] != null:
				var text = "#%d - %s - %s - %s - %s (F: %d, A: %d, Arm: %d, M: %d)" % [
					home_team[i].number, home_team[i].name, home_team[i].position, 
					home_team[i].race, home_team[i].state.capitalize(),
					home_team[i].stats.strength, home_team[i].stats.agility,
					home_team[i].stats.armor, home_team[i].stats.movement
				]
				home_team_list.add_item(text, null, false)
				if home_team[i].state == "herido":
					home_team_list.set_item_custom_fg_color(i, Color.RED)
				elif home_team[i].state == "jugando":
					home_team_list.set_item_custom_fg_color(i, Color.GREEN)
				else:  # sano
					home_team_list.set_item_custom_fg_color(i, Color.WHITE)
			else:
				home_team_list.add_item("Vacío #%d" % [i + 1], null, false)
	
	if away_team_list:
		away_team_list.clear()
		for i in range(away_team.size()):
			if away_team[i] != null:
				var text = "#%d - %s - %s - %s - %s (F: %d, A: %d, Arm: %d, M: %d)" % [
					away_team[i].number, away_team[i].name, away_team[i].position, 
					away_team[i].race, away_team[i].state.capitalize(),
					away_team[i].stats.strength, away_team[i].stats.agility,
					away_team[i].stats.armor, away_team[i].stats.movement
				]
				away_team_list.add_item(text, null, false)
				if away_team[i].state == "herido":
					away_team_list.set_item_custom_fg_color(i, Color.RED)
				elif away_team[i].state == "jugando":
					away_team_list.set_item_custom_fg_color(i, Color.GREEN)
				else:  # sano
					away_team_list.set_item_custom_fg_color(i, Color.WHITE)
			else:
				away_team_list.add_item("Vacío #%d" % [i + 1], null, false)

# Actualiza los labels de puntaje, heridas, tiempo y directo
func update_labels():
	if score_label:
		score_label.text = "Touchdowns: Casa %d - %d Visitante" % [score[0], score[1]]
	if injury_label:
		injury_label.text = "Heridas: Casa %d - %d Visitante" % [injuries[0], injuries[1]]
	if time_label:
		if is_halftime:
			time_label.text = "Entretempo"
		else:
			time_label.text = "Tiempo: %d seg" % current_time
	if directo_label:
		directo_label.text = "[b]Directo[/b]\n"
		for play in plays:
			if play.begins_with("Intercambio:") or play.begins_with("¡El equipo") or play.begins_with("¡Fin del partido!") or play.begins_with("[Entretempo]"):
				directo_label.text += "[i]%s[/i]\n" % play
			else:
				directo_label.text += "%s\n" % play

# Simula el partido con jugadas cada segundo
func start_match_simulation():
	# Primera parte: 10 segundos, 10 eventos
	for i in range(10):
		# Verificar si algún equipo se quedó sin jugadores
		var active_home_players = home_team.filter(func(p): return p != null and p.state == "jugando")
		var active_away_players = away_team.filter(func(p): return p != null and p.state == "jugando")
		if active_home_players.is_empty():
			plays.append("¡El equipo local se queda sin jugadores! El equipo visitante gana.")
			score[1] += 2  # +2 touchdowns para el equipo visitante
			update_labels()
			update_team_lists()
			save_player_team()
			exit_match_button.disabled = false
			return
		if active_away_players.is_empty():
			plays.append("¡El equipo visitante se queda sin jugadores! El equipo local gana.")
			score[0] += 2  # +2 touchdowns para el equipo local
			update_labels()
			update_team_lists()
			save_player_team()
			exit_match_button.disabled = false
			return
		
		current_time = i  # Actualizar tiempo
		var play = generate_random_play()
		if play != "":
			plays.append(play)
		update_labels()
		update_team_lists()
		await get_tree().create_timer(1.0).timeout  # 1 evento por segundo
	
	# Entretempo: 5 segundos
	is_halftime = true
	plays.append("[Entretempo] %s" % play_templates["halftime_plays"].pick_random())
	update_labels()
	await get_tree().create_timer(5.0).timeout  # Duración del entretiempo
	
	# Segunda parte: 10 segundos, 10 eventos
	is_halftime = false
	for i in range(10):
		# Verificar si algún equipo se quedó sin jugadores
		var active_home_players = home_team.filter(func(p): return p != null and p.state == "jugando")
		var active_away_players = away_team.filter(func(p): return p != null and p.state == "jugando")
		if active_home_players.is_empty():
			plays.append("¡El equipo local se queda sin jugadores! El equipo visitante gana.")
			score[1] += 2
			update_labels()
			update_team_lists()
			save_player_team()
			exit_match_button.disabled = false
			return
		if active_away_players.is_empty():
			plays.append("¡El equipo visitante se queda sin jugadores! El equipo local gana.")
			score[0] += 2
			update_labels()
			update_team_lists()
			save_player_team()
			exit_match_button.disabled = false
			return
		
		current_time = i  # Actualizar tiempo
		var play = generate_random_play()
		if play != "":
			plays.append(play)
		update_labels()
		update_team_lists()
		await get_tree().create_timer(1.0).timeout  # 1 evento por segundo
	
	# Fin del partido
	plays.append("¡Fin del partido!")
	update_labels()
	save_player_team()
	exit_match_button.disabled = false

# Genera una jugada aleatoria usando plantillas
func generate_random_play():
	var active_home_players = home_team.filter(func(p): return p != null and p.state == "jugando")
	var active_away_players = away_team.filter(func(p): return p != null and p.state == "jugando")
	if active_home_players.is_empty() or active_away_players.is_empty():
		return "Partido detenido: No hay jugadores activos suficientes."
	
	var action = ["pass_success", "pass_failure", "touchdown_success", "touchdown_failure", 
				  "injury_success", "injury_failure", "dodge_success", "dodge_failure", "filler"].pick_random()
	var team = ["home", "away"].pick_random()
	var player = (active_home_players if team == "home" else active_away_players).pick_random()
	
	var play_text = play_templates["plays"][action].pick_random().format({"player": "%s (#%d)" % [player.name, player.number]})
	
	# Aplicar colores según el tipo de jugada
	if action == "injury_success":
		play_text = "[color=red]%s[/color]" % play_text
	elif action == "touchdown_success":
		play_text = "[color=green]%s[/color]" % play_text
	elif action in ["injury_failure", "touchdown_failure"]:
		play_text = "[color=blue]%s[/color]" % play_text
	
	match action:
		"touchdown_success":
			score[0 if team == "home" else 1] += 1
		"injury_success":
			# Lesionar a un jugador del equipo contrario
			var opponent_team = active_away_players if team == "home" else active_home_players
			if not opponent_team.is_empty():
				var opponent = opponent_team.pick_random()
				opponent.state = "herido"
				injuries[0 if team == "home" else 1] += 1
				plays.append(play_text)  # Añadir jugada de lesión primero
				# Jugada extra: sustitución (no cuenta como evento)
				var substitute = substitute_player("away" if team == "home" else "home", opponent)
				if substitute:
					plays.append("Intercambio: %s (#%d) entra por %s (#%d)." % [substitute.name, substitute.number, opponent.name, opponent.number])
				else:
					plays.append("¡El equipo %s no tiene reservas! Continúan con menos jugadores." % ("Casa" if team == "home" else "Visitante"))
				return ""  # Evitar duplicar la jugada de lesión
		"injury_failure":
			# Lesionar al jugador actual
			player.state = "herido"
			injuries[1 if team == "home" else 0] += 1  # El equipo contrario provoca la lesión
			plays.append(play_text)  # Añadir jugada de lesión primero
			# Jugada extra: sustitución (no cuenta como evento)
			var substitute = substitute_player(team, player)
			if substitute:
				plays.append("Intercambio: %s (#%d) entra por %s (#%d)." % [substitute.name, substitute.number, player.name, player.number])
			else:
				plays.append("¡El equipo %s no tiene reservas! Continúan con menos jugadores." % ("Casa" if team == "home" else "Visitante"))
			return ""  # Evitar duplicar la jugada de lesión
	
	return play_text

# Sustituye un jugador lesionado para mantener 11 jugadores activos
func substitute_player(team_name: String, injured_player: Dictionary):
	var team = home_team if team_name == "home" else away_team
	var active_players = team.filter(func(p): return p != null and p.state == "jugando")
	if active_players.size() >= 11:
		return null  # No es necesario sustituir si ya hay 11 activos
	
	var substitute = team.filter(func(p): return p != null and p.state == "sano").pick_random()
	if substitute:
		substitute.state = "jugando"
		save_player_team()
		update_team_lists()  # Actualizar colores dinámicamente
		return substitute
	return null

# Guarda el equipo del jugador en player_team.json
func save_player_team():
	var file = FileAccess.open("res://Resources/player_team.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players": home_team}, "\t"))
		file.close()

# Maneja el botón de salir
func _on_exit_match_button_pressed():
	# Resetear estados "jugando" a "sano"
	for i in range(home_team.size()):
		if home_team[i] != null and home_team[i].state == "jugando":
			home_team[i].state = "sano"
	save_player_team()
	var team_management_scene = load("res://Scenes/TeamManagement.tscn").instantiate()
	get_tree().root.add_child(team_management_scene)
	get_tree().current_scene = team_management_scene
	queue_free()
