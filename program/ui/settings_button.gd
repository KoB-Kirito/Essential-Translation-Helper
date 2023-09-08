extends TextureButton


@export var normal_color: Color = Color.WHITE
@export var pressed_color: Color = Color.WHITE
@export var hover_color: Color = Color.WHITE


func _init() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	toggled.connect(_on_toggled)


func _ready() -> void:
	if button_pressed:
		modulate = pressed_color
	else:
		modulate = normal_color


func _on_mouse_entered() -> void:
	if not disabled:
		modulate = hover_color


func _on_mouse_exited() -> void:
	if button_pressed:
		modulate = pressed_color
	else:
		modulate = normal_color


func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		modulate = pressed_color
	else:
		modulate = normal_color
