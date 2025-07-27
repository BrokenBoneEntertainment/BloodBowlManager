extends Control

# User credentials storage
var users = []

# UI node references
@onready var title_label = $UIContainer/TitleLabel
@onready var username_input = $UIContainer/UsernameInput
@onready var password_input = $UIContainer/PasswordInput
@onready var login_button = $UIContainer/LoginButton
@onready var create_user_button = $UIContainer/CreateUserButton
@onready var message_label = $UIContainer/MessageLabel
@onready var create_user_popup = $UIContainer/CreateUserPopup
@onready var popup_username_input = $UIContainer/CreateUserPopup/PopupContent/PopupUsernameInput
@onready var popup_password_input = $UIContainer/CreateUserPopup/PopupContent/PopupPasswordInput
@onready var popup_verify_password_input = $UIContainer/CreateUserPopup/PopupContent/PopupVerifyPasswordInput
@onready var confirm_create_button = $UIContainer/CreateUserPopup/PopupContent/ConfirmCreateButton
@onready var cancel_create_button = $UIContainer/CreateUserPopup/PopupContent/CancelCreateButton
@onready var popup_message_label = $UIContainer/CreateUserPopup/PopupContent/PopupMessageLabel

# Called when the node is ready
func _ready():
	load_users()
	if not title_label or not username_input or not password_input or not login_button or not create_user_button or not message_label or not create_user_popup or not popup_username_input or not popup_password_input or not popup_verify_password_input or not confirm_create_button or not cancel_create_button or not popup_message_label:
		show_message("Error: UI nodes not found")
		return
	title_label.text = "Blood Bowl Manager (Pre-Alpha)"
	username_input.text = ""
	username_input.placeholder_text = "Usuario"
	password_input.text = ""
	password_input.placeholder_text = "Contraseña"
	password_input.secret = true  # Enable password mode
	message_label.text = ""
	initialize_popup()
	# Connect signals programmatically
	login_button.pressed.connect(_on_login_button_pressed)
	create_user_button.pressed.connect(_on_create_user_button_pressed)
	confirm_create_button.pressed.connect(_on_confirm_create_button_pressed)
	cancel_create_button.pressed.connect(_on_cancel_create_button_pressed)

# Initializes popup state
func initialize_popup():
	create_user_popup.hide()
	popup_username_input.text = ""
	popup_password_input.text = ""
	popup_verify_password_input.text = ""
	popup_message_label.text = ""
	popup_password_input.secret = true  # Enable password mode
	popup_verify_password_input.secret = true  # Enable password mode
	popup_username_input.placeholder_text = "Usuario"
	popup_password_input.placeholder_text = "Contraseña"
	popup_verify_password_input.placeholder_text = "Confirmar contraseña"

# Loads users from users.json
func load_users():
	var file = FileAccess.open("res://Resources/users.json", FileAccess.READ)
	if file:
		var json = JSON.parse_string(file.get_as_text())
		users = json.get("users", [])
		file.close()
	else:
		users = []
		save_users()

# Saves users to users.json
func save_users():
	var file = FileAccess.open("res://Resources/users.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"users": users}, "\t"))
		file.close()

# Handles login button press
func _on_login_button_pressed():
	var username = username_input.text.strip_edges()
	var password = password_input.text.strip_edges()
	
	if username == "" or password == "":
		show_message("Por favor, introduce usuario y contraseña.")
		return
	
	var user = users.filter(func(u): return u.username == username)
	if user.size() == 0:
		show_message("El usuario no existe.")
		return
	if user[0].password != password:
		show_message("Contraseña incorrecta.")
		return
	
	show_message("¡Login exitoso! Cargando menú principal...")
	Global.current_user = username  # Store current user globally
	var main_scene = load("res://Scenes/Main.tscn").instantiate()
	get_tree().root.add_child(main_scene)
	get_tree().current_scene = main_scene
	queue_free()

# Handles create user button press
func _on_create_user_button_pressed():
	initialize_popup()
	create_user_popup.popup_centered()

# Handles confirm create button press in popup
func _on_confirm_create_button_pressed():
	var username = popup_username_input.text.strip_edges()
	var password = popup_password_input.text.strip_edges()
	var verify_password = popup_verify_password_input.text.strip_edges()
	
	if username == "" or password == "" or verify_password == "":
		show_popup_message("Por favor, completa todos los campos.")
		return
	
	if password != verify_password:
		show_popup_message("Las contraseñas no coinciden.")
		return
	
	if users.any(func(u): return u.username == username):
		show_popup_message("El usuario ya existe.")
		return
	
	users.append({"username": username, "password": password})
	save_users()
	show_popup_message("Usuario creado. Ahora puedes iniciar sesión.")
	await get_tree().create_timer(2.0).timeout
	create_user_popup.hide()

# Handles cancel create button press in popup
func _on_cancel_create_button_pressed():
	create_user_popup.hide()
	show_popup_message("Creación de usuario cancelada.")

# Displays a temporary message in main UI
func show_message(message: String):
	if message_label:
		message_label.text = message
		await get_tree().create_timer(3.0).timeout
		message_label.text = ""

# Displays a temporary message in popup
func show_popup_message(message: String):
	if popup_message_label:
		popup_message_label.text = message
		await get_tree().create_timer(3.0).timeout
		popup_message_label.text = ""
