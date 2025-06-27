extends Panel

signal replacement_selected(dead_position: int, replacement_position: int)

@onready var title_label = $VBoxContainer/TitleLabel
@onready var position_label = $VBoxContainer/PositionLabel
@onready var choices_container = $VBoxContainer/ChoicesContainer

var dead_position: int = -1
var available_positions: Array = []
var battle_manager_ref = null  # Store reference to battle manager

func setup_replacement(dead_pos: int, available: Array, battle_manager = null):
	dead_position = dead_pos
	available_positions = available
	battle_manager_ref = battle_manager
	
	# Set labels
	title_label.text = "Select Replacement"
	var row = (dead_pos / 8) + 1
	var col = (dead_pos % 8) + 1
	position_label.text = "Position: Row %d, Column %d" % [row, col]
	
	# Clear previous choices
	for child in choices_container.get_children():
		child.queue_free()
	
	# Add choice buttons for each available soldier
	for pos in available:
		var soldier = get_soldier_at_position(pos)
		if soldier:
			var button = Button.new()
			var soldier_row = (pos / 8) + 1
			var soldier_col = (pos % 8) + 1
			button.text = "%s (R%d,C%d) - H:%d M:%d" % [
				soldier.soldier_name,
				soldier_row,
				soldier_col,
				soldier.health,
				soldier.morale
			]
			button.pressed.connect(_on_replacement_selected.bind(pos))
			choices_container.add_child(button)

func _on_replacement_selected(replacement_pos: int):
	replacement_selected.emit(dead_position, replacement_pos)
	queue_free()

func get_soldier_at_position(pos: int) -> Soldier:
	# Get soldier from battle manager if available
	if battle_manager_ref and pos < battle_manager_ref.soldiers_reference.size():
		return battle_manager_ref.soldiers_reference[pos]
	
	# Fallback to formation
	var formation = get_node_or_null("/root/Main/FormationGrid")
	if formation and pos < formation.soldiers.size():
		return formation.soldiers[pos]
	return null

func _ready():
	# Position panel in center
	custom_minimum_size = Vector2(400, 300)
	position = Vector2(760, 390)
	modulate = Color.WHITE
	z_index = 20  # Appear on top
