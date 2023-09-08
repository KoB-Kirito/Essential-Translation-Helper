extends MenuButton
# Info menu button. Shared between main and editor


@export var license_popup: PopupPanel


func _ready() -> void:
	get_popup().id_pressed.connect(_on_info_menu_button_pressed)


func _on_info_menu_button_pressed(id: int) -> void:
	match id:
		0: # HowTo
			OS.shell_open("https://github.com/KoB-Kirito/Intl-File-Merger")
		1: # Update
			OS.shell_open("https://github.com/KoB-Kirito/Intl-File-Merger/releases")
		2: # Report a bug
			OS.shell_open("https://github.com/KoB-Kirito/Intl-File-Merger/issues")
		3: # License
			license_popup.popup()
