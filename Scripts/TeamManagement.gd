extends Control

var team = []  # Lista de jugadores (24 posiciones, null para vacías)
var position_limits = {
	"Fighter": 8,
	"Defender": 16,
	"Thrower": 4,
	"Runner": 4
}
var first_names = []  # Lista de nombres
var titles = []  # Lista de títulos
var delete_mode = false  # Estado del modo de eliminación
var delete_index = -1  # Índice del jugador a eliminar

# Inicializa la escena, carga nombres, configura UI y carga equipo del jugador
func _ready():
	var file = FileAccess.open("res://Resources/player_names.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		first_names = json["first_names"]
		titles = json["titles"]
		file.close()
	else:
		show_message("Error: No se pudo cargar player_names.json")
	
	# Cargar equipo del jugador desde JSON
	load_player_team()
	
	if $UIContainer/WarningLabel:
		$UIContainer/WarningLabel.text = ""
	if $UIContainer/CustomNameInput:
		$UIContainer/CustomNameInput.text = ""
	
	update_team_list()
	if $UIContainer/MatchStrategy:
		$UIContainer/MatchStrategy.clear()
		$UIContainer/MatchStrategy.add_item("Ofensiva", 0)
		$UIContainer/MatchStrategy.add_item("Defensiva", 1)
		$UIContainer/MatchStrategy.add_item("Equilibrada", 2)
	if $UIContainer/PositionSelector:
		$UIContainer/PositionSelector.clear()
		$UIContainer/PositionSelector.add_item("Fighter", 0)
		$UIContainer/PositionSelector.add_item("Defender", 1)
		$UIContainer/PositionSelector.add_item("Thrower", 2)
		$UIContainer/PositionSelector.add_item("Runner", 3)

# Carga el equipo del jugador desde player_team.json
func load_player_team():
	var file = FileAccess.open("res://Resources/player_team.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		team = json["players"]
		file.close()
	else:
		team.resize(24)
		for i in range(24):
			team[i] = null

# Guarda el equipo del jugador en player_team.json
func save_player_team():
	var file = FileAccess.open("res://Resources/player_team.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"players": team}, "\t"))
		file.close()

# Contrata un jugador y lo coloca en la posición más baja vacía
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
			if $UIContainer/CustomNameInput:
				$UIContainer/CustomNameInput.text = ""
		else:
			show_message("No hay posiciones disponibles.")

# Activa el modo de eliminación
func _on_delete_player_button_pressed():
	if not $UIContainer/DeletePlayerButton:
		return
	if not delete_mode:
		delete_mode = true
		delete_index = -1
		$UIContainer/DeletePlayerButton.text = "PULSA FUERA PARA CANCELAR"
		if $UIContainer/ItemList:
			$UIContainer/ItemList.deselect_all()
		show_message("Selecciona un jugador para eliminar.")

# Inicia un partido cargando Match.tscn
func _on_play_match_button_pressed():
	var player_count = get_player_count()
	if player_count < 11:
		show_message("Necesitas al menos 11 jugadores para jugar un partido. Tienes: " + str(player_count))
		return
	# Marcar los primeros 11 jugadores no nulos como "jugando"
	var active_count = 0
	for i in range(team.size()):
		if team[i] != null and active_count < 11 and team[i].state != "herido":
			team[i].state = "jugando"
			active_count += 1
		elif team[i] != null and team[i].state != "herido":
			team[i].state = "sano"  # Resto al banquillo
	save_player_team()
	var match_scene = load("res://Scenes/Match.tscn").instantiate()
	get_tree().root.add_child(match_scene)
	get_tree().current_scene = match_scene
	queue_free()

# Crea un nuevo jugador con posición, nombre y estadísticas
func create_player():
	if not $UIContainer/PositionSelector:
		show_message("Error: PositionSelector no encontrado.")
		return null
	var selected_index = $UIContainer/PositionSelector.selected
	if selected_index == -1:
		show_message("Selecciona una posición.")
		return null
	var position = $UIContainer/PositionSelector.get_item_text(selected_index)
	if can_add_position(position):
		var name = ""
		var custom_name = $UIContainer/CustomNameInput.text.strip_edges() if $UIContainer/CustomNameInput else ""
		if custom_name != "":
			name = custom_name
			if team.any(func(p): return p != null and p.name == name):
				show_message("El nombre " + name + " ya está en uso.")
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
			"number": 0,  # Se asignará en update_team_list
			"race": "Human",
			"stats": get_stats_for_position(position),
			"state": "sano"  # Nuevo jugador empieza como sano
		}
		return player
	else:
		show_message("Límite de " + position + " alcanzado.")
		return null

# Limpia el campo de nombre personalizado
func _on_clear_name_button_pressed():
	if $UIContainer/CustomNameInput:
		$UIContainer/CustomNameInput.text = ""
	show_message("Nombre limpiado.")

# Selecciona jugador para eliminar en modo eliminación
func _on_item_list_item_clicked(index: int, at_position: Vector2, mouse_button_index: int):
	if mouse_button_index == MOUSE_BUTTON_LEFT and index >= 0 and index < team.size() and delete_mode and team[index] != null:
		delete_index = index
		if $UIContainer/ConfirmDeletePopup and $UIContainer/ConfirmDeletePopup/PopupContainer/Label:
			$UIContainer/ConfirmDeletePopup/PopupContainer/Label.text = "¿Eliminar a " + team[index].name + "?"
			$UIContainer/ConfirmDeletePopup.popup_centered()
		if $UIContainer/ItemList:
			$UIContainer/ItemList.deselect_all()

# Deselecciona al hacer clic fuera de ItemList
func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var item_list_rect = $UIContainer/ItemList.get_global_rect() if $UIContainer/ItemList else Rect2()
		if not item_list_rect.has_point(event.global_position):
			if $UIContainer/ItemList:
				$UIContainer/ItemList.deselect_all()
			if delete_mode:
				delete_mode = false
				delete_index = -1
				if $UIContainer/DeletePlayerButton:
					$UIContainer/DeletePlayerButton.text = "Eliminar Jugador"
				if $UIContainer/ConfirmDeletePopup:
					$UIContainer/ConfirmDeletePopup.hide()
				show_message("Eliminación cancelada.")
			update_team_list()

# Confirma la eliminación del jugador
func _on_confirm_delete_button_pressed():
	if delete_index >= 0 and delete_index < team.size() and team[delete_index] != null:
		var player_name = team[delete_index].name
		team[delete_index] = null
		update_team_list()
		save_player_team()
		show_message("Jugador " + player_name + " eliminado.")
	delete_mode = false
	delete_index = -1
	if $UIContainer/DeletePlayerButton:
		$UIContainer/DeletePlayerButton.text = "Eliminar Jugador"
	if $UIContainer/ConfirmDeletePopup:
		$UIContainer/ConfirmDeletePopup.hide()
	if $UIContainer/ItemList:
		$UIContainer/ItemList.deselect_all()

# Cancela la eliminación desde el popup
func _on_cancel_delete_button_pressed():
	delete_mode = false
	delete_index = -1
	if $UIContainer/DeletePlayerButton:
		$UIContainer/DeletePlayerButton.text = "Eliminar Jugador"
	if $UIContainer/ConfirmDeletePopup:
		$UIContainer/ConfirmDeletePopup.hide()
	show_message("Eliminación cancelada.")
	if $UIContainer/ItemList:
		$UIContainer/ItemList.deselect_all()

# Muestra un mensaje temporal en WarningLabel
func show_message(message: String):
	if $UIContainer/WarningLabel:
		$UIContainer/WarningLabel.text = message
		var timer = get_tree().create_timer(3.0)
		await timer.timeout
		$UIContainer/WarningLabel.text = ""

# Devuelve combinaciones de nombres disponibles
func get_available_name_combinations():
	var combinations = []
	for fname in first_names:
		for title in titles:
			var full_name = fname + " " + title
			if not team.any(func(p): return p != null and p.name == full_name):
				combinations.append(full_name)
	return combinations

# Verifica si se puede añadir un jugador en la posición dada
func can_add_position(position):
	var count = 0
	for player in team:
		if player != null and player.position == position:
			count += 1
	return count < position_limits[position]

# Devuelve estadísticas según la posición
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

# Cuenta los jugadores no nulos
func get_player_count():
	var count = 0
	for player in team:
		if player != null:
			count += 1
	return count

# Actualiza ItemList con jugadores y posiciones vacías
func update_team_list():
	if not $UIContainer/ItemList:
		return
	$UIContainer/ItemList.clear()
	for i in range(team.size()):
		if team[i] != null:
			team[i].number = i + 1  # Asigna número según posición
			var text = "#%d - %s - %s - %s - %s (F: %d, A: %d, Arm: %d, M: %d)" % [
				i + 1, team[i].name, team[i].position, team[i].race, team[i].state.capitalize(),
				team[i].stats.strength, team[i].stats.agility,
				team[i].stats.armor, team[i].stats.movement
			]
			$UIContainer/ItemList.add_item(text, null, true)
			if team[i].state == "herido":
				$UIContainer/ItemList.set_item_custom_fg_color(i, Color.RED)
			else:  # sano
				$UIContainer/ItemList.set_item_custom_fg_color(i, Color.WHITE)
		else:
			$UIContainer/ItemList.add_item("Vacío #%d" % [i + 1], null, true)
	$UIContainer/ItemList.deselect_all()  # Deseleccionar al actualizar
