extends CanvasLayer

@onready var container: HBoxContainer = $Panel/CardContainer
@onready var panel: PanelContainer = $Panel

var _current_choices: Array = []


func _ready() -> void:
	panel.visible = false
	GameEvents.show_level_up_ui.connect(_on_show)
	GameEvents.hide_level_up_ui.connect(_on_hide)


func _on_show(choices: Array) -> void:
	_current_choices = choices
	get_tree().paused = true
	panel.visible = true
	_build_cards(choices)


func _on_hide() -> void:
	get_tree().paused = false
	panel.visible = false
	_clear_cards()


func _build_cards(choices: Array) -> void:
	_clear_cards()
	for i in range(choices.size()):
		var blessing: BlessingData = choices[i]
		var card := _create_card(blessing, i)
		container.add_child(card)


func _create_card(blessing: BlessingData, index: int) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(140, 180)
	card.text = "%s\n\n%s\n\nDMG: %d\nCD: %.1fs" % [
		blessing.name,
		blessing.description,
		blessing.damage,
		blessing.cooldown,
	]
	card.pressed.connect(_on_card_pressed.bind(index))
	return card


func _on_card_pressed(index: int) -> void:
	if index < _current_choices.size():
		GameEvents.blessing_chosen.emit(_current_choices[index])


func _clear_cards() -> void:
	for child in container.get_children():
		child.queue_free()
