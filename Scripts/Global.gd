extends Node

var current_user = ""
var current_team = ""

const MAX_TEAMS = 5  # Definir un valor por defecto

static func sanitize_filename(input: String) -> String:
	if not input:
		return "default"
	var invalid_chars = ["%", "/", "\\", ":", "*", "?", "\"", "<", ">", "|"]
	var sanitized = input
	for char in invalid_chars:
		sanitized = sanitized.replace(char, "_")
	sanitized = sanitized.strip_edges().replace(" ", "_")
	return sanitized if sanitized else "default"
