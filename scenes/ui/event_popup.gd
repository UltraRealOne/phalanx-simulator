extends Control

signal choice_made(choice_index: int)

@onready var panel = $Panel
@onready var event_title = $Panel/VBoxContainer/EventTitle
@onready var event_text = $Panel/VBoxContainer/EventText
@onready var choices_container = $Panel/VBoxContainer/ChoicesContainer
@onready var close_button = $Panel/VBoxContainer/CloseButton

var current_event: GameEvent
var involved_soldiers: Array = []

func setup_event(event: GameEvent, soldiers: Array):
	current_event = event
	involved_soldiers = soldiers
	
	# Set title and text
	event_title.text = event.event_name
	event_text.text = format_event_text(event.event_text, soldiers)
	
	# Clear previous choices
	for child in choices_container.get_children():
		child.queue_free()
	
	# Add choice buttons
	for i in range(event.choices.size()):
		var choice = event.choices[i]
		var button = Button.new()
		button.text = format_event_text(choice.choice_text, soldiers)
		button.pressed.connect(_on_choice_pressed.bind(i))
		
		# Add tooltip showing consequences
		var consequences_preview = choice.get_consequences_preview(involved_soldiers)
		if consequences_preview != "":
			button.tooltip_text = consequences_preview
		
		# Make button expand to full width
		button.custom_minimum_size.x = 560
		
		choices_container.add_child(button)
	
	# Setup close button for events with no choices
	if event.choices.size() == 0:
		close_button.visible = true
		close_button.pressed.connect(_on_close_pressed)
	else:
		close_button.visible = false

func format_event_text(text: String, soldiers: Array) -> String:
	var formatted = text
	
	# Replace soldier placeholders
	if soldiers.size() > 0:
		var pos1 = soldiers[0].get_meta("grid_position", -1)
		var row1 = pos1 / 8 + 1 if pos1 != -1 else 0
		var col1 = pos1 % 8 + 1 if pos1 != -1 else 0
		var soldier1_text = "%s (R%d,C%d)" % [soldiers[0].soldier_name, row1, col1]
		formatted = formatted.replace("[SOLDIER1]", soldier1_text)
		
	if soldiers.size() > 1:
		var pos2 = soldiers[1].get_meta("grid_position", -1)
		var row2 = pos2 / 8 + 1 if pos2 != -1 else 0
		var col2 = pos2 % 8 + 1 if pos2 != -1 else 0
		var soldier2_text = "%s (R%d,C%d)" % [soldiers[1].soldier_name, row2, col2]
		formatted = formatted.replace("[SOLDIER2]", soldier2_text)
	
	# Replace stat placeholders
	# [SOLDIER1_MORALE], [SOLDIER2_HEALTH], etc.
	# TODO: Implement more sophisticated text replacement
	
	return formatted

func _on_choice_pressed(choice_index: int):
	choice_made.emit(choice_index)
	queue_free()

func _on_close_pressed():
	queue_free()

func _ready():
	# Make sure popup appears on top
	self.z_index = 10
	# Make the panel background solid, not transparent
	panel.modulate = Color.WHITE
