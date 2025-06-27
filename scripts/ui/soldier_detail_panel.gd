extends Panel

@onready var name_label = $VBoxContainer/NameLabel
@onready var nationality_label = $VBoxContainer/NationalityLabel
@onready var age_label = $VBoxContainer/AgeLabel
@onready var tab_container = $VBoxContainer/TabContainer

# Update these paths to match your new structure with VBoxContainers
@onready var stats_container = $VBoxContainer/TabContainer/Stats/VBoxContainer/StatsContainer
@onready var traits_container = $VBoxContainer/TabContainer/Stats/VBoxContainer/TraitsContainer
@onready var relationship_tab = $VBoxContainer/TabContainer/Relationships

var current_soldier: Soldier = null
var current_soldier_index: int = -1
var relationship_manager = null

signal tab_changed(tab_idx: int)

func _ready():
	# Hide panel initially
	visible = false
	
	# Make sure panel renders behind its children
	self.z_index = -1
	self.show_behind_parent = true
	
	# Connect relationship tab signals with error checking
	if relationship_tab:
		print("Relationship tab found: ", relationship_tab.name)
		print("Relationship tab script: ", relationship_tab.get_script())
		
		# Check if signals exist before connecting
		var signals = relationship_tab.get_script().get_script_signal_list() if relationship_tab.get_script() else []
		var has_friend_signal = false
		var has_rival_signal = false
		
		
		for signal_info in signals:
			print("Available signal: ", signal_info.name)
			if signal_info.name == "friend_selected":
				has_friend_signal = true
			elif signal_info.name == "rival_selected":
				has_rival_signal = true
		
		if has_friend_signal:
			relationship_tab.friend_selected.connect(_on_relationship_selected)
		else:
			print("Warning: friend_selected signal not found in relationship_tab")
			
		if has_rival_signal:
			relationship_tab.rival_selected.connect(_on_relationship_selected)
		else:
			print("Warning: rival_selected signal not found in relationship_tab")
	else:
		print("Warning: relationship_tab not found")
	
	if tab_container:
		tab_container.tab_changed.connect(_on_tab_container_changed)
	
	# Find relationship manager
	call_deferred("_find_relationship_manager")

func _find_relationship_manager():
	relationship_manager = get_node_or_null("/root/Main/FormationGrid/RelationshipManager")
	if not relationship_manager:
		var nodes = get_tree().get_nodes_in_group("relationship_manager")
		if nodes.size() > 0:
			relationship_manager = nodes[0]

func display_soldier(soldier: Soldier, soldier_index: int = -1):
	# Clear previous data
	clear_display()
	
	# Store current soldier reference
	current_soldier = soldier
	current_soldier_index = soldier_index
	
	# Show panel
	visible = true
	
	# Display basic info
	name_label.text = soldier.soldier_name
	nationality_label.text = "Nationality: " + soldier.nationality
	age_label.text = "Age: " + str(soldier.age)
	
	# Add commander button if not already commander AND not in battle
	var formation_grid_node = get_node_or_null("/root/Main/FormationGrid")
	var is_in_battle = formation_grid_node and formation_grid_node.is_battle_active
	
	# Only add promote button if NOT in battle and not already a commander
	if not soldier.soldier_name.begins_with("Commander ") and not soldier.soldier_name.begins_with("Acting Commander ") and not is_in_battle:
		# Add button to the stats tab
		var stats_promote_button = Button.new()
		stats_promote_button.text = "Promote to Commander"
		stats_promote_button.pressed.connect(_on_promote_pressed)
		
		# Add to bottom of traits container parent (VBoxContainer)
		if traits_container and traits_container.get_parent():
			traits_container.get_parent().add_child(stats_promote_button)
		
		# Add button to the relationships tab too
		if relationship_tab:
			var relationship_promote_button = Button.new()
			relationship_promote_button.text = "Promote to Commander"
			relationship_promote_button.pressed.connect(_on_promote_pressed)
			
			# If relationship tab has a VBoxContainer as parent, add to that
			if relationship_tab is Control and relationship_tab.get_child_count() > 0:
				var parent = relationship_tab.get_child(0)
				if parent is VBoxContainer:
					parent.add_child(relationship_promote_button)
				else:
					relationship_tab.add_child(relationship_promote_button)
			else:
				relationship_tab.add_child(relationship_promote_button)
	
	# Display stats
	add_stat_display("Health", soldier.health, Color.RED)
	add_stat_display("Morale", soldier.morale, Color.YELLOW)
	add_stat_display("Andreia", soldier.andreia, Color.ORANGE)
	add_stat_display("Logos", soldier.logos, Color.PURPLE)
	
	# Display traits
	for current_trait in soldier.traits:
		add_trait_display(current_trait)
	
	# Display relationships tab if relationships exist
	if relationship_tab and relationship_manager:
		var formation_grid_reference = get_node_or_null("/root/Main/FormationGrid")
		if formation_grid_reference:
			relationship_tab.display_relationships(
				soldier,
				formation_grid_reference.soldiers,
				relationship_manager
			)

func _on_promote_pressed():
	if current_soldier_index >= 0:
		# Call promote function in formation grid
		var formation_grid = get_node_or_null("/root/Main/FormationGrid")
		if formation_grid and formation_grid.has_method("promote_to_commander"):
			formation_grid.promote_to_commander(current_soldier_index)
			# Refresh display
			display_soldier(current_soldier, current_soldier_index)

func clear_display():
	# Clear all children of the main container except the labels and containers
	var main_container = name_label.get_parent()
	for child in main_container.get_children():
		if child != name_label and child != nationality_label and child != age_label and child != tab_container:
			child.queue_free()
	
	# Check if stats_container exists before clearing
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()
	else:
		print("Warning: stats_container is null")
	
	# Check if traits_container exists before clearing
	if traits_container:
		for child in traits_container.get_children():
			child.queue_free()
	else:
		print("Warning: traits_container is null")
	
	# Also clear any promote buttons from the tab VBoxContainers
	var stats_tab = tab_container.get_node_or_null("Stats")
	if stats_tab:
		var stats_vbox = stats_tab.get_node_or_null("VBoxContainer")
		if stats_vbox:
			for child in stats_vbox.get_children():
				if child is Button:
					child.queue_free()
	
	var relationships_tab = tab_container.get_node_or_null("Relationships")
	if relationships_tab:
		var relationships_vbox = relationships_tab.get_node_or_null("VBoxContainer")
		if relationships_vbox:
			for child in relationships_vbox.get_children():
				if child is Button:
					child.queue_free()

func add_stat_display(stat_name: String, value: int, color: Color):
	# Check if stats_container exists
	if not stats_container:
		print("Error: stats_container is null when adding stat display")
		return
	
	var stat_row = HBoxContainer.new()
	
	var label = Label.new()
	label.text = stat_name + ": "
	label.custom_minimum_size.x = 100
	label.add_theme_color_override("font_color", Color.WHITE)
	stat_row.add_child(label)
	
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 20)
	bar.max_value = 20
	bar.value = value
	bar.modulate = color
	stat_row.add_child(bar)
	
	var value_label = Label.new()
	value_label.text = str(value)
	value_label.add_theme_color_override("font_color", Color.WHITE)
	stat_row.add_child(value_label)
	
	stats_container.add_child(stat_row)

func add_trait_display(current_trait: Trait):
	# Check if traits_container exists
	if not traits_container:
		print("Error: traits_container is null when adding trait display")
		return
	
	var trait_label = Label.new()
	trait_label.text = "• " + current_trait.trait_name
	trait_label.add_theme_color_override("font_color", Color.WHITE)
	trait_label.custom_minimum_size.x = 300  # Set minimum width
	trait_label.mouse_filter = Control.MOUSE_FILTER_STOP
	trait_label.tooltip_text = current_trait.description
	
	traits_container.add_child(trait_label)

func _on_relationship_selected(other_soldier: Soldier):
	# Find the soldier's index in the formation grid
	var formation_grid_node = get_node_or_null("/root/Main/FormationGrid")
	if formation_grid_node:
		for i in range(formation_grid_node.soldiers.size()):
			if formation_grid_node.soldiers[i] and formation_grid_node.soldiers[i].id == other_soldier.id:
				# Select that soldier's slot
				formation_grid_node.select_slot(formation_grid_node.soldier_slots[i])
				return

func _on_tab_container_changed(tab_idx: int):
	tab_changed.emit(tab_idx)
