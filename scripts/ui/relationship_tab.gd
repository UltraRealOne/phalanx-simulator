extends Control

signal friend_selected(soldier: Soldier)
signal rival_selected(soldier: Soldier)

@onready var friends_container = $VBoxContainer/FriendsContainer/VBoxContainer
@onready var rivals_container = $VBoxContainer/RivalsContainer/VBoxContainer
@onready var neutral_label = $VBoxContainer/NeutralContainer/Label

var current_soldier: Soldier = null
var all_soldiers: Array[Soldier] = []
var relationship_manager = null

# Colors for relationship display
var friend_color = Color(0, 0.6, 0)
var rival_color = Color(0.9, 0, 0)

func _ready():
	# Ensure the containers exist
	if not friends_container or not rivals_container:
		print("Warning: Relationship tab containers not found")
		print("Friends container: ", friends_container)
		print("Rivals container: ", rivals_container)
		print("Path to self: ", get_path())
		# Print children to debug
		for child in get_children():
			print("Child: ", child.name)
			if child is VBoxContainer:
				for subchild in child.get_children():
					print("  - ", subchild.name)

func display_relationships(soldier: Soldier, soldiers: Array[Soldier], rel_manager):
	# Clear previous data
	clear_display()
	
	# Store references
	current_soldier = soldier
	all_soldiers = soldiers
	relationship_manager = rel_manager
	
	# Count neutral relationships
	var friends_count = 0
	var rivals_count = 0
	var neutral_count = 0
	
	# Get soldier's relationships
	for other_id in soldier.relationships:
		var other_soldier = null
		# Find the soldier in the array
		for s in all_soldiers:
			if s and s.id == other_id:
				other_soldier = s
				break
				
		if not other_soldier or not other_soldier.is_alive:
			continue
			
		var value = soldier.relationships[other_id]
		
		# Categorize relationship
		if value >= relationship_manager.FRIEND_THRESHOLD:
			add_relationship_item(other_soldier, value, true)
			friends_count += 1
		elif value <= relationship_manager.RIVAL_THRESHOLD:
			add_relationship_item(other_soldier, value, false)
			rivals_count += 1
		else:
			neutral_count += 1
	
	# Update neutral count
	if neutral_label:
		neutral_label.text = "Neutral: " + str(neutral_count)
	
	# Update container labels
	var friends_label = $VBoxContainer/FriendsContainer/Label
	var rivals_label = $VBoxContainer/RivalsContainer/Label
	
	if friends_label:
		friends_label.text = "Friends (" + str(friends_count) + ")"
	
	if rivals_label:
		rivals_label.text = "Rivals (" + str(rivals_count) + ")"

func clear_display():
	# Clear relationship containers
	if friends_container:
		for child in friends_container.get_children():
			child.queue_free()
	else:
		print("Warning: friends_container is null")
		
	if rivals_container:
		for child in rivals_container.get_children():
			child.queue_free()
	else:
		print("Warning: rivals_container is null")

func add_relationship_item(other_soldier: Soldier, value: int, is_friend: bool):
	var container = friends_container if is_friend else rivals_container
	if not container:
		print("Warning: Container is null for relationship item")
		return
		
	var color = friend_color if is_friend else rival_color
	
	# Create button for selectable relationship
	var button = Button.new()
	button.text = other_soldier.soldier_name
	button.add_theme_color_override("font_color", color)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Add value as additional text
	var relationship_type = "Unknown"
	if relationship_manager:
		relationship_type = relationship_manager.get_relationship_type(value)
	button.text += " (" + relationship_type + ")"
	
	# Connect button signal
	if is_friend:
		button.pressed.connect(_on_friend_selected.bind(other_soldier))
	else:
		button.pressed.connect(_on_rival_selected.bind(other_soldier))
	
	# Add to appropriate container
	container.add_child(button)

func _on_friend_selected(soldier: Soldier):
	friend_selected.emit(soldier)

func _on_rival_selected(soldier: Soldier):
	rival_selected.emit(soldier)
