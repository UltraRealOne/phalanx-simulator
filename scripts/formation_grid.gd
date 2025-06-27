extends Node2D

const RelationshipManager = preload("res://scripts/relationship/relationship_manager.gd")

# Grid configuration
const ROWS = 3
const COLUMNS = 8
const SLOT_SIZE = Vector2(100, 100)
const SLOT_SPACING = 10

# Grid data
var soldier_slots = []
var selected_slot = null

# Soldier data
var soldiers: Array[Soldier] = []
var soldier_displays: Array = []
var soldier_generator: SoldierGenerator

# Drag and drop
var dragging_soldier: Soldier = null
var drag_origin_index: int = -2
var drag_preview: Control = null
var is_battle_active: bool = false  # Add this to track battle state

# Relationship visualization
var relationship_manager: RelationshipManager
var relationship_values_labels = []
var current_tab_is_relationships = false

# Cohesion display
var cohesion_display: Label
var current_cohesion: float = 0.0

# Tooltip variables
var relationship_tooltip: PanelContainer = null
var current_tooltip_soldier: Soldier = null
var currently_hovering: bool = false
var hover_timer: Timer = null
var tooltip_update_queued: bool = false
var current_hover_soldier: Soldier = null
var hover_slot: Panel = null

# UI references
@onready var grid_container = $GridContainer

func _ready():
	soldier_generator = SoldierGenerator.new()
	add_child(soldier_generator)
	create_grid()
	position_grid()
	populate_initial_soldiers()
	setup_relationship_system()
	create_test_relationships()
	set_process_input(true)
	setup_cohesion_display()
	setup_relationship_tooltip()
	
	# Calculate initial cohesion after a slight delay
	call_deferred("_calculate_and_update_cohesion")
	
	# Add test button for events (temporary)
	var test_button = Button.new()
	test_button.text = "Trigger Test Event"
	test_button.position = Vector2(900, 400)
	test_button.pressed.connect(_on_test_event_pressed)
	add_child(test_button)
	
	# Add test button for battle (temporary)
	var battle_button = Button.new()
	battle_button.text = "Start Battle"
	battle_button.position = Vector2(900, 100)
	battle_button.pressed.connect(_on_battle_button_pressed)
	add_child(battle_button)
	
	# Add specific event buttons for testing
	var event1_button = Button.new()
	event1_button.text = "Event 1"
	event1_button.position = Vector2(900, 150)
	event1_button.pressed.connect(_on_specific_event_pressed.bind("test_event_1"))
	add_child(event1_button)
	
	var event2_button = Button.new()
	event2_button.text = "Event 2"
	event2_button.position = Vector2(900, 200)
	event2_button.pressed.connect(_on_specific_event_pressed.bind("test_event_2"))
	add_child(event2_button)
	
	var event3_button = Button.new()
	event3_button.text = "Event 3"
	event3_button.position = Vector2(900, 250)
	event3_button.pressed.connect(_on_specific_event_pressed.bind("test_event_3"))
	add_child(event3_button)
	
	# Add kill commander test button
	var kill_commander_button = Button.new()
	kill_commander_button.text = "Kill Commander"
	kill_commander_button.position = Vector2(900, 300)
	kill_commander_button.pressed.connect(_on_kill_commander_test)
	add_child(kill_commander_button)
	
	# Add test funeral button (temporary)
	var funeral_button = Button.new()
	funeral_button.text = "Test Funeral"
	funeral_button.position = Vector2(900, 350)
	funeral_button.pressed.connect(_on_test_funeral)
	add_child(funeral_button)
	
	# Add a relationship test button
	var relationship_test_button = Button.new()
	relationship_test_button.text = "Test Relationships"
	relationship_test_button.position = Vector2(900, 450)
	relationship_test_button.pressed.connect(_on_relationship_test)
	add_child(relationship_test_button)
	
	# Add a "Next Turn" test button
	var turn_button = Button.new()
	turn_button.text = "Next Turn"
	turn_button.position = Vector2(900, 500)
	turn_button.pressed.connect(_on_next_turn)
	add_child(turn_button)
	
	# Add a "Reset Relationships" button
	var reset_relationships_button = Button.new()
	reset_relationships_button.text = "Reset Relationships"
	reset_relationships_button.position = Vector2(900, 550)
	reset_relationships_button.pressed.connect(_on_reset_relationships)
	add_child(reset_relationships_button)
	
	# Defer event system initialization
	call_deferred("_initialize_event_system")
	
	# Connect tab change signal
	var detail_panel = $"../UI/SoldierDetailPanel"
	if detail_panel and detail_panel.has_signal("tab_changed"):
		detail_panel.tab_changed.connect(_on_tab_changed)
	
	# Create hover timer for relationship tooltips
	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.7  # 700ms delay before showing tooltip
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

func _initialize_event_system():
	# Wait a frame to ensure EventManager is loaded
	await get_tree().process_frame
	
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		event_manager.set_soldiers_reference(soldiers)
	else:
		print("Error: EventManager not found!")

func _on_test_event_pressed():
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		event_manager.check_for_events("peaceful")
	else:
		print("Error: EventManager not found!")

func create_grid():
	# Configure GridContainer
	grid_container.columns = COLUMNS
	grid_container.add_theme_constant_override("h_separation", SLOT_SPACING)
	grid_container.add_theme_constant_override("v_separation", SLOT_SPACING)
	
	# Create main formation grid
	for row in range(ROWS):
		for col in range(COLUMNS):
			var slot = create_slot(row * COLUMNS + col)
			soldier_slots.append(slot)
			grid_container.add_child(slot)

func create_slot(index: int):
	# Create individual slot
	var slot = Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	
	# Use StyleBoxFlat for the background instead of modulate
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.29, 0.29, 1.0)  # Dark background color
	slot.add_theme_stylebox_override("panel", style)
	
	# Keep modulate at full white so children aren't dimmed
	slot.modulate = Color.WHITE
	
	# Store slot data
	slot.set_meta("index", index)
	
	# Add slot functionality
	slot.gui_input.connect(_on_slot_input.bind(slot))
	slot.mouse_entered.connect(_on_slot_hover.bind(slot, true))
	slot.mouse_exited.connect(_on_slot_hover.bind(slot, false))
	
	return slot

func position_grid():
	# Center the entire formation on screen
	var viewport_size = get_viewport_rect().size
	var grid_width = COLUMNS * SLOT_SIZE.x + (COLUMNS - 1) * SLOT_SPACING
	var grid_height = ROWS * SLOT_SIZE.y + (ROWS - 1) * SLOT_SPACING
	
	position.x = (viewport_size.x - grid_width) / 2
	position.y = (viewport_size.y - grid_height) / 2 + 50

func populate_initial_soldiers():
	# Generate 24 soldiers total
	for i in range(24):
		var soldier = soldier_generator.generate_soldier("Macedonian")
		soldiers.append(soldier)
		update_slot_display(i, soldier)
	
	# Select the soldier with highest logos as initial commander
	var best_logos = 0
	var best_index = 0
	
	for i in range(soldiers.size()):
		if soldiers[i].logos > best_logos:
			best_logos = soldiers[i].logos
			best_index = i
	
	# Add commander title
	promote_to_commander(best_index)

func promote_to_commander(index: int):
	# Safety check
	if index < 0 or index >= soldiers.size() or not soldiers[index] or not soldiers[index].is_alive:
		print("Error: Invalid soldier for promotion at index ", index)
		return
	
	# Remove previous commander or acting commander title if any
	for i in range(soldiers.size()):
		if soldiers[i] and soldiers[i].is_alive:
			if soldiers[i].soldier_name.begins_with("Commander "):
				soldiers[i].soldier_name = soldiers[i].soldier_name.substr(10)
				update_slot_display(i, soldiers[i])
				print("Previous commander demoted: ", soldiers[i].soldier_name)
			elif soldiers[i].soldier_name.begins_with("Acting Commander "):
				soldiers[i].soldier_name = soldiers[i].soldier_name.substr(17)
				# Remove temp commander flag
				if soldiers[i].has_meta("temp_commander"):
					soldiers[i].remove_meta("temp_commander")
				update_slot_display(i, soldiers[i])
				print("Acting commander demoted: ", soldiers[i].soldier_name)
	
	# Add commander title to new commander
	soldiers[index].soldier_name = "Commander " + soldiers[index].soldier_name
	
	# Remove any temp commander flag if it exists
	if soldiers[index].has_meta("temp_commander"):
		soldiers[index].remove_meta("temp_commander")
	
	update_slot_display(index, soldiers[index])
	print("New commander promoted: ", soldiers[index].soldier_name)
	
	# Recalculate cohesion after commander change
	calculate_cohesion_value()
	update_cohesion_display()

func update_slot_display(index: int, soldier: Soldier):
	var slot = soldier_slots[index]
	
	# Clear existing children
	for child in slot.get_children():
		child.queue_free()
	
	var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		slot.add_theme_stylebox_override("panel", style)
	
	# Handle null soldiers (empty slots)
	if soldier == null:
		style.bg_color = Color(0.29, 0.29, 0.29, 1.0)
		slot.set_meta("empty", true)
		return
	
	# Add soldier display if soldier exists and is alive
	if soldier.is_alive:
		var display = create_soldier_display(soldier)
		slot.add_child(display)
		slot.set_meta("empty", false)
		style.bg_color = Color(0.29, 0.29, 0.29, 1.0) # Reset to normal color
	else:
		# Dead soldiers - clear the slot
		style.bg_color = Color(0.29, 0.29, 0.29, 0.29)
		slot.set_meta("empty", true)

func create_soldier_display(soldier: Soldier) -> Control:
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation", 2)
	
	# Name label
	var name_label = Label.new()
	name_label.text = soldier.soldier_name
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_color", Color.WHITE)
	container.add_child(name_label)
	
	# Stats container
	var stats_container = HBoxContainer.new()
	stats_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_container.add_theme_constant_override("separation", 3)
	
	# Health bar
	var health_bar = create_stat_bar(soldier.health, Color.RED)
	stats_container.add_child(health_bar)
	
	# Morale bar
	var morale_bar = create_stat_bar(soldier.morale, Color.YELLOW)
	stats_container.add_child(morale_bar)
	
	container.add_child(stats_container)
	
	return container

func create_stat_bar(value: int, color: Color) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(40, 5)
	bar.max_value = 20
	bar.value = value
	bar.show_percentage = false
	bar.modulate = color
	return bar

func _on_slot_input(event: InputEvent, slot: Panel):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				select_slot(slot)
				# Start drag on press
				if selected_slot:
					start_drag()
			else:
				# End drag on release
				if dragging_soldier:
					end_drag()

func _on_slot_hover(slot: Panel, is_hovering: bool):
	# Visual feedback for hover
	if slot != selected_slot:
		var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			if is_hovering:
				style.bg_color = Color(0.35, 0.35, 0.35, 1.0)  # Lighter grey on hover
				
				# Store hover slot and start timer for tooltip if in relationships tab
				if current_tab_is_relationships and selected_slot:
					hover_slot = slot
					hover_timer.start()
			else:
				# When hover ends
				if slot.get_meta("empty", false):
					if slot.get_meta("normal_empty", false):
						# Normal empty slots (replacements) use normal color
						style.bg_color = Color(0.29, 0.29, 0.29, 1.0)
					else:
						# Dead soldier slots use darker grey
						style.bg_color = Color(0.29, 0.29, 0.29, 1.0)
				else:
					# Regular slots use normal color
					style.bg_color = Color(0.29, 0.29, 0.29, 1.0)
				
				# Stop timer and hide tooltip
				hover_timer.stop()
				hover_slot = null
				
				# Hide tooltip if it exists
				if relationship_tooltip:
					relationship_tooltip.visible = false

func _on_hover_timer_timeout():
	# Check if we have a valid hover slot
	if hover_slot and selected_slot and current_tab_is_relationships:
		# Get the selected soldier
		var selected_index = selected_slot.get_meta("index")
		if selected_index < soldiers.size():
			var selected_soldier = soldiers[selected_index]
			
			# Get the hovered soldier
			var hover_index = hover_slot.get_meta("index")
			if hover_index < soldiers.size():
				var hover_soldier = soldiers[hover_index]
				
				# Make sure both soldiers are valid and different
				if selected_soldier and hover_soldier and selected_soldier != hover_soldier and hover_soldier.is_alive:
					# Update and show the tooltip
					update_relationship_tooltip(selected_soldier, hover_soldier)
					show_relationship_tooltip(get_global_mouse_position())

func select_slot(slot: Panel):
	# Don't select empty slots
	if slot.get_meta("empty", false):
		return
	
	# Deselect previous slot
	if selected_slot:
		var prev_style = selected_slot.get_theme_stylebox("panel") as StyleBoxFlat
		if prev_style:
			prev_style.bg_color = Color(0.29, 0.29, 0.29, 1.0)
	
	# Select new slot
	selected_slot = slot
	var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color = Color(0.42, 0.42, 0.42, 1.0)
	
	# Update detail panel with soldier info
	var index = slot.get_meta("index")
	if index < soldiers.size():
		var soldier = soldiers[index]
		if soldier and soldier.is_alive:
			update_detail_panel(soldier, index)
			
			# Display relationship values if on relationships tab
			display_relationship_values(soldier, current_tab_is_relationships)

func update_detail_panel(soldier: Soldier, index: int):
	# Calculate position
	var row = index / COLUMNS + 1
	var col = index % COLUMNS + 1
	
	# Remove the info_label.text update
	# Just update the detailed panel
	var detail_panel = $"../UI/SoldierDetailPanel"
	if detail_panel and detail_panel.has_method("display_soldier"):
		detail_panel.display_soldier(soldier, index)

# Drag and Drop functions
func _input(event):
	if event is InputEventMouseMotion and dragging_soldier:
		update_drag_preview(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if dragging_soldier:
				end_drag()

func start_drag():
	# Don't allow dragging during battle or for dead soldiers
	if is_battle_active:
		return
		
	if selected_slot == null:
		return
	
	var index = get_slot_index(selected_slot)
	if index < 0 or index >= soldiers.size():
		return
	# Check if soldier is alive
	var soldier = soldiers[index]
	if not soldier.is_alive:
		return
		
	dragging_soldier = soldiers[index]
	drag_origin_index = index
	
	# Create drag preview with proper container
	drag_preview = Control.new()
	drag_preview.custom_minimum_size = SLOT_SIZE
	drag_preview.size = drag_preview.custom_minimum_size
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var display = create_soldier_display(dragging_soldier)
	drag_preview.add_child(display)
	drag_preview.modulate.a = 0.7  # Make slightly transparent
	
	get_viewport().add_child(drag_preview)
	
	# Set initial position
	update_drag_preview(get_viewport().get_mouse_position())

func end_drag():
	if not dragging_soldier:
		return
	
	# Find target slot
	var target_slot = get_slot_at_position(get_global_mouse_position())
	if target_slot:
		var target_index = get_slot_index(target_slot)
		var origin_index = drag_origin_index
		
		if target_index >= 0:
			swap_soldiers(origin_index, target_index)
			
			# Select the dragged soldier in its new position
			select_slot(soldier_slots[target_index])
	
	# Clean up
	if drag_preview:
		drag_preview.queue_free()
	dragging_soldier = null
	drag_origin_index = -2

func update_drag_preview(mouse_pos: Vector2):
	if drag_preview:
		drag_preview.position = mouse_pos - drag_preview.size / 2

func swap_soldiers(from_index: int, to_index: int):
	# Simple array swap
	var temp = soldiers[from_index]
	soldiers[from_index] = soldiers[to_index]
	soldiers[to_index] = temp
	
	# Update displays
	update_slot_display(from_index, soldiers[from_index])
	update_slot_display(to_index, soldiers[to_index])
	
	# Recalculate and update cohesion since formation changed
	calculate_cohesion_value()
	update_cohesion_display()

func get_slot_index(slot: Panel) -> int:
	var index = soldier_slots.find(slot)
	return index

func get_slot_at_position(mouse_pos: Vector2) -> Panel:
	for slot in soldier_slots:
		if slot.get_global_rect().has_point(mouse_pos):
			return slot
	
	return null

func update_soldier_at_position(position_index: int, soldier: Soldier):
	# Update the display
	update_slot_display(position_index, soldier)
	
	# Flash the slot to show it changed
	flash_slot(position_index)
	
	# If this soldier is currently selected, update the detail panel
	if selected_slot:
		var selected_index = selected_slot.get_meta("index")
		if selected_index == position_index:
			update_detail_panel(soldier, position_index)

# Add flash effect when stats change
func flash_slot(index: int):
	if index < 0 or index >= soldier_slots.size():
		return
	
	var slot = soldier_slots[index]
	var original_color = slot.modulate
	
	# Flash yellow
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(slot, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(slot, "modulate", original_color, 0.3)

func _on_specific_event_pressed(event_id: String):
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		if event_manager.has_method("trigger_specific_event"):
			event_manager.trigger_specific_event(event_id)
		else:
			for method in event_manager.get_method_list():
				print("  - ", method.name)
	else:
		print("Error: EventManager not found!")

func _on_battle_button_pressed():
	# Load battle data
	var battles_file = FileAccess.open("res://data/battles/historical_battles.json", FileAccess.READ)
	if battles_file:
		var json_string = battles_file.get_as_text()
		battles_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var battles_data = json.data
			if battles_data.size() > 0:
				# Use first battle for testing
				start_battle(battles_data[0])

func start_battle(battle_data: Dictionary):
	is_battle_active = true  # Set battle state
	
	# Create battle screen
	var battle_screen = preload("res://scenes/ui/battle_screen.tscn").instantiate()
	get_tree().root.add_child(battle_screen)
	
	# Setup battle
	battle_screen.setup_battle(battle_data, self, soldiers)
	
	# Connect to signals BEFORE starting the battle
	battle_screen.battle_manager.battle_ended.connect(_on_battle_ended)
	battle_screen.battle_manager.replacement_needed.connect(_on_replacement_needed)
	battle_screen.battle_manager.cohesion_changed.connect(_on_cohesion_changed)
	
	# Connect to casualties signal
	battle_screen.battle_manager.casualties_occurred.connect(_on_casualties_occurred)
	
	# NOW start the battle - after signals are connected
	battle_screen.start_battle()
	
	# Immediately force sync our display
	if battle_screen.battle_manager:
		current_cohesion = battle_screen.battle_manager.current_cohesion
		update_cohesion_display()
		print("Battle started - force synced cohesion to: ", current_cohesion)

func _on_battle_ended():
	is_battle_active = false  # Reset battle state
	
	# Disconnect from the battle manager signals
	var battle_screen = get_node_or_null("/root/BattleScreen")
	if battle_screen and battle_screen.battle_manager:
		if battle_screen.battle_manager.is_connected("cohesion_changed", Callable(self, "_on_cohesion_changed")):
			battle_screen.battle_manager.cohesion_changed.disconnect(_on_cohesion_changed)
	
	# Recalculate cohesion after battle ends
	calculate_cohesion_value()
	update_cohesion_display()

func _on_replacement_needed(empty_slots: Array):
	# For now, just print the empty slots
	print("Need replacements for slots: ", empty_slots)

func update_soldier_death(position: int):
	if position < 0 or position >= soldier_slots.size():
		return
		
	var slot = soldier_slots[position]
	
	# Clear the slot completely
	for child in slot.get_children():
		child.queue_free()
		
	# Update the StyleBox instead of using modulate
	var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		slot.add_theme_stylebox_override("panel", style)
	
	# Mark slot as empty
	slot.set_meta("empty", true)
	slot.set_meta("normal_empty", false)  # Not a normal empty slot
	
	# Flash red to show death - using the StyleBox instead of modulate
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	
	# Modify the StyleBox color directly
	tween.tween_callback(func():
		style.bg_color = Color(0.5, 0, 0, 1.0)  # Darker red that's still visible
	)
	tween.tween_interval(0.1)
	tween.tween_callback(func():
		style.bg_color = Color(0.29, 0.29, 0.29, 1.0)  # Back to darker grey
	)
	
	# Update relationship values if needed
	if current_tab_is_relationships and selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var selected_soldier = soldiers[index]
			if selected_soldier:
				display_relationship_values(selected_soldier, true)

func apply_replacement(dead_position: int, replacement_position: int):
	# Get the replacement soldier
	var replacement_soldier = soldiers[replacement_position]
	
	# Move soldier to new position
	soldiers[dead_position] = replacement_soldier
	soldiers[replacement_position] = null
	
	# Update the new position display
	update_slot_display(dead_position, replacement_soldier)
	
	# Update the old position - using normal color (not dark)
	var old_slot = soldier_slots[replacement_position]
	
	# Clear any children in the old slot
	for child in old_slot.get_children():
		child.queue_free()
	
	# Update the StyleBox to normal color (not dark)
	var style = old_slot.get_theme_stylebox("panel") as StyleBoxFlat
	if not style:
		style = StyleBoxFlat.new()
		old_slot.add_theme_stylebox_override("panel", style)
	
	# Set to normal color (0.29 is the normal slot color)
	style.bg_color = Color(0.29, 0.29, 0.29, 1.0)  # Normal slot color
	
	# Mark slot as empty but use normal color
	old_slot.set_meta("empty", true)
	old_slot.set_meta("normal_empty", true)  # Flag to distinguish from dead soldiers
	
	# Flash the destination slot to make the change more visible
	var dest_slot = soldier_slots[dead_position]
	var dest_style = dest_slot.get_theme_stylebox("panel") as StyleBoxFlat
	if dest_style:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func():
			dest_style.bg_color = Color(0.4, 0.4, 0.7, 1.0)  # Blue highlight
		)
		tween.tween_interval(0.1)
		tween.tween_callback(func():
			dest_style.bg_color = Color(0.29, 0.29, 0.29, 1.0)  # Normal color
		)
	
	# Update relationship values if needed
	if current_tab_is_relationships and selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var selected_soldier = soldiers[index]
			if selected_soldier:
				display_relationship_values(selected_soldier, true)

func apply_replacement_sync(dead_position: int, replacement_position: int, replacement_soldier: Soldier):
	# Update our array to match battle manager's array
	soldiers[dead_position] = replacement_soldier
	soldiers[replacement_position] = null
	
	# Update the displays
	update_slot_display(dead_position, replacement_soldier)
	update_slot_display(replacement_position, null)
	
	# Flash the slot to make the change more visible
	var slot = soldier_slots[dead_position]
	var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var original_color = style.bg_color
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func():
			style.bg_color = Color(0.4, 0.4, 0.7, 1.0)  # Blue highlight
		)
		tween.tween_interval(0.1)
		tween.tween_callback(func():
			style.bg_color = Color(0.29, 0.29, 0.29, 1.0)  # Normal color
		)

func _on_kill_commander_test():
	if not is_battle_active:
		print("No battle active - start a battle first")
		return
	
	# Find the commander or acting commander
	var commander = null
	var commander_id = ""
	
	for soldier in soldiers:
		if soldier and soldier.is_alive:
			if soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander "):
				commander = soldier
				commander_id = soldier.id
				break
	
	if commander and commander.is_alive:
		print("Testing commander death for: ", commander.soldier_name)
		
		# Get the battle screen and trigger commander death
		var battle_screen = get_node_or_null("/root/BattleScreen")
		if battle_screen and battle_screen.battle_manager:
			# Print the current cohesion before death
			var before_cohesion = battle_screen.battle_manager.current_cohesion
			print("Before commander death - cohesion: ", before_cohesion)
			
			# Call execute_death directly with the commander's ID
			battle_screen.battle_manager.execute_death(commander_id)
			
			# Wait a moment for death processing
			await get_tree().create_timer(0.2).timeout
			
			# Print after death
			var after_cohesion = battle_screen.battle_manager.current_cohesion
			print("After commander death - cohesion: ", after_cohesion)
			print("Cohesion reduction: ", (1.0 - after_cohesion/before_cohesion) * 100.0, "%")
			
			# Also update expected casualties
			print("Expected casualties: ", battle_screen.battle_manager.expected_casualties)
		else:
			print("Battle manager not found")
	else:
		print("No commander or acting commander found")

func create_test_relationships():
	# Check if relationship manager exists
	if relationship_manager:
		print("RelationshipManager already initialized relationships")
		# Do NOT call initialize_relationships again, as it's already been called in setup_relationship_system
		
		# Instead, let's just print some relationship info
		var relationship_count = 0
		var strong_relationship_count = 0
		
		for i in range(soldiers.size()):
			var soldier1 = soldiers[i]
			if not soldier1:
				continue
			
			for j in range(i + 1, soldiers.size()):
				var soldier2 = soldiers[j]
				if not soldier2:
					continue
				
				if soldier2.id in soldier1.relationships:
					relationship_count += 1
					var value = soldier1.relationships[soldier2.id]
					if abs(value) >= 30:
						strong_relationship_count += 1
		
		print("Found %d relationships, %d strong ones" % [relationship_count, strong_relationship_count])
	else:
		print("Warning: RelationshipManager not available, using fallback method")
		
		# Fallback method - original code
		# (Keep the rest of the original function)

func _on_test_funeral():
	# Find a soldier with the most relationships
	var most_relationships_soldier = null
	var max_relationships = 0
	
	for soldier in soldiers:
		if soldier and soldier.relationships.size() > max_relationships:
			max_relationships = soldier.relationships.size()
			most_relationships_soldier = soldier
	
	print("Testing funeral with soldier who has %d relationships: %s" % [
		max_relationships, most_relationships_soldier.soldier_name
	])
	
	# Get some dead soldiers for testing
	var test_fallen: Array[Soldier] = []
	test_fallen.append(most_relationships_soldier)
	
	# Get survivors (everyone except the fallen)
	var survivors: Array[Soldier] = []
	for soldier in soldiers:
		if soldier and soldier != most_relationships_soldier:
			survivors.append(soldier)
	
	# Create funeral screen
	var funeral_screen = preload("res://scenes/funeral_screen.tscn").instantiate()
	get_tree().root.add_child(funeral_screen)
	funeral_screen.setup_funeral(test_fallen, survivors)

func setup_relationship_system():
	# Check if relationship system is already set up
	if relationship_manager != null:
		print("Relationship system already initialized")
		return
	
	# Create manager (no need for canvas or container anymore)
	relationship_manager = RelationshipManager.new()
	relationship_manager.formation_grid = self
	relationship_manager.add_to_group("relationship_manager")
	add_child(relationship_manager)
	
	# Initialize relationships
	relationship_manager.initialize_relationships(soldiers)
	
	# Connect signals
	relationship_manager.relationship_changed.connect(_on_relationship_changed)
	relationship_manager.significant_relationship_formed.connect(_on_significant_relationship)
	
func get_soldier_position(soldier: Soldier) -> int:
	for i in range(soldiers.size()):
		if soldiers[i] == soldier:
			return i
	return -1

func _on_relationship_changed(soldier1_id: String, soldier2_id: String, value: int):
	# If selected soldier is involved, update the display
	if selected_slot and current_tab_is_relationships:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var selected_soldier = soldiers[index]
			if selected_soldier and (selected_soldier.id == soldier1_id || selected_soldier.id == soldier2_id):
				# Update the relationship values display
				display_relationship_values(selected_soldier, true)
	
	# Update cohesion
	update_cohesion_display()

func _on_significant_relationship(soldier1: Soldier, soldier2: Soldier, is_positive: bool):
	# Trigger a notification
	var message = "%s and %s have %s" % [
		soldier1.soldier_name,
		soldier2.soldier_name,
		"become friends" if is_positive else "developed a rivalry"
	]
	
	# Add notification
	add_notification(message, 5.0)
	
	# Update detail panel if necessary
	if selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var selected_soldier = soldiers[index]
			if selected_soldier and (selected_soldier.id == soldier1.id || selected_soldier.id == soldier2.id):
				update_detail_panel(selected_soldier, index)

# This function is still needed for notifications
func add_notification(message: String, duration: float = 3.0):
	var notification = Label.new()
	notification.text = message
	notification.add_theme_font_size_override("font_size", 16)
	notification.position = Vector2(400, 50)
	add_child(notification)
	
	# Fade out and remove
	var tween = create_tween()
	tween.tween_property(notification, "modulate:a", 0.0, duration)
	tween.tween_callback(notification.queue_free)

func find_soldier_by_id(id: String) -> Soldier:
	for soldier in soldiers:
		if soldier and soldier.id == id:
			return soldier
	return null

func _on_relationship_test():
	# Modify this function to just update a random relationship value
	# Find two soldiers with an existing relationship
	var strongest_relationship = 0
	var soldier1_index = -1
	var soldier2_index = -1
	
	# Find the strongest relationship
	for i in range(soldiers.size()):
		var soldier1 = soldiers[i]
		if not soldier1 or not soldier1.is_alive:
			continue
			
		for j in range(i + 1, soldiers.size()):
			var soldier2 = soldiers[j]
			if not soldier2 or not soldier2.is_alive:
				continue
				
			if soldier2.id in soldier1.relationships:
				var value = abs(soldier1.relationships[soldier2.id])
				if value > strongest_relationship:
					strongest_relationship = value
					soldier1_index = i
					soldier2_index = j
	
	if soldier1_index >= 0 and soldier2_index >= 0:
		var soldier1 = soldiers[soldier1_index]
		var soldier2 = soldiers[soldier2_index]
		var current_value = soldier1.relationships[soldier2.id]
		
		print("Strongest relationship: %s <-> %s: %d" % [
			soldier1.soldier_name,
			soldier2.soldier_name,
			current_value
		])
		
		# Modify the relationship to test updates
		if relationship_manager:
			var new_value = 10 if current_value < 0 else -10  # Flip the direction
			print("Changing relationship by %d" % new_value)
			relationship_manager.modify_relationship(
				soldier1.id,
				soldier2.id,
				new_value
			)
			
			# Select one of the soldiers to see the updated relationship
			select_slot(soldier_slots[soldier1_index])
	else:
		print("No relationships found to test")

func update_turn():
	# This would be called when a turn ends
	if relationship_manager:
		relationship_manager.update_relationships(1.0)  # Delta of 1.0 represents one turn
		
		# Update detail panel if a soldier is selected
		if selected_slot:
			var index = selected_slot.get_meta("index")
			if index < soldiers.size():
				var soldier = soldiers[index]
				if soldier and soldier.is_alive:
					update_detail_panel(soldier, index)

func _on_next_turn():
	print("Turn updated")
	update_turn()

func _on_reset_relationships():
	print("Resetting relationships with much more diversity...")
	
	# Clear existing relationships
	for soldier in soldiers:
		if soldier:
			soldier.relationships.clear()
	
	# Create a relationship generator with modified settings
	var relationship_generator = RelationshipGenerator.new()
	
	# Generate new relationships
	relationship_generator.generate_initial_relationships(soldiers, relationship_manager.compatibility_matrix)
	
	# Add some guaranteed extreme relationships for testing
	var total_soldiers = soldiers.size()
	for i in range(5):  # Create 5 strong negative relationships
		var idx1 = randi() % total_soldiers
		var idx2 = randi() % total_soldiers
		if idx1 != idx2 and soldiers[idx1] and soldiers[idx2]:
			var value = -randi_range(70, 100)
			soldiers[idx1].relationships[soldiers[idx2].id] = value
			soldiers[idx2].relationships[soldiers[idx1].id] = value
			print("Created forced negative relationship: %s <-> %s: %d" % [
				soldiers[idx1].soldier_name, soldiers[idx2].soldier_name, value
			])
	
	# Update detail panel if needed
	if selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var soldier = soldiers[index]
			if soldier:
				update_detail_panel(soldier, index)
	
	print("Relationships reset with much more diversity")

func display_relationship_values(soldier: Soldier, show: bool):
	# Clear any existing relationship value labels
	for label in relationship_values_labels:
		if is_instance_valid(label):
			label.queue_free()
	relationship_values_labels.clear()
	
	# If not showing or no relationship manager, return early
	if not show or not relationship_manager or not soldier:
		return
	
	# For each soldier in the formation, display their relationship to the selected soldier
	for i in range(soldiers.size()):
		var other_soldier = soldiers[i]
		if not other_soldier or not other_soldier.is_alive or other_soldier == soldier:
			continue
		
		# Check if there's a relationship between them
		if other_soldier.id in soldier.relationships:
			var value = soldier.relationships[other_soldier.id]
			
			# Create a label for the relationship value (no value check)
			var value_label = Label.new()
			value_label.text = str(value)
			
			# Set color based on relationship value
			if value > 0:
				value_label.add_theme_color_override("font_color", Color(0, 0.7, 0))  # Green
			elif value < 0:
				value_label.add_theme_color_override("font_color", Color(0.7, 0, 0))  # Red
			else:
				value_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # Gray for zero
			
			# Make the text bold for better visibility
			value_label.add_theme_font_size_override("font_size", 14)
			
			# Position the label at the soldier's slot
			var slot = soldier_slots[i]
			value_label.position = Vector2(
				slot.position.x + slot.size.x / 2 - value_label.size.x / 2,
				slot.position.y + slot.size.y - 20  # Bottom of the slot
			)
			
			# Add to grid
			add_child(value_label)
			relationship_values_labels.append(value_label)

func _on_tab_changed(tab_idx: int):
	# Update whether the current tab is the relationships tab
	current_tab_is_relationships = (tab_idx == 1)  # Assuming relationships is the second tab (index 1)
	
	# If not on relationships tab, hide tooltip
	if not current_tab_is_relationships:
		hide_relationship_tooltip()
	
	# Get the selected soldier if any
	var selected_soldier = null
	if selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			selected_soldier = soldiers[index]
	
	# Display or hide relationship values
	display_relationship_values(selected_soldier, current_tab_is_relationships)

func setup_cohesion_display():
	# Create a label for cohesion
	cohesion_display = Label.new()
	cohesion_display.text = "Formation Cohesion: 0.0"
	cohesion_display.add_theme_font_size_override("font_size", 18)
	
	# Create a details button
	var details_button = Button.new()
	details_button.text = "Details"
	details_button.custom_minimum_size = Vector2(60, 30)
	details_button.pressed.connect(_on_cohesion_details_pressed)
	
	# Create an HBoxContainer to hold both the label and button
	var hbox = HBoxContainer.new()
	hbox.add_child(cohesion_display)
	hbox.add_child(details_button)
	
	# Create a stylish panel to hold the container
	var panel = PanelContainer.new()
	panel.add_child(hbox)
	
	# Add some padding
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	panel.add_theme_stylebox_override("panel", style)
	
	# Calculate correct position under the grid
	var grid_width = COLUMNS * SLOT_SIZE.x + (COLUMNS - 1) * SLOT_SPACING
	var grid_height = ROWS * SLOT_SIZE.y + (ROWS - 1) * SLOT_SPACING
	
	# Get the global position of the grid
	var grid_global_pos = grid_container.global_position
	
	# Set the position to be centered at the bottom of the grid
	panel.global_position = Vector2(
		grid_global_pos.x + grid_width/2 - panel.size.x/2,  # Center horizontally
		grid_global_pos.y + grid_height + 10                # 10 pixels below grid
	)
	
	# Add to scene using a CanvasLayer to ensure consistent positioning
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 1  # Above grid but below other UI
	canvas_layer.name = "CohesionDisplayLayer"
	add_child(canvas_layer)
	canvas_layer.add_child(panel)
	
	# Wait one frame to get the correct panel size
	await get_tree().process_frame
	
	# Reposition after panel size is known
	panel.global_position = Vector2(
		grid_global_pos.x + grid_width/2 - panel.size.x/2,  # Center horizontally
		grid_global_pos.y + grid_height + 10                # 10 pixels below grid
	)
	
	# Calculate the initial cohesion value
	calculate_cohesion_value()
	
	# Update cohesion display with the calculated value
	update_cohesion_display()

func calculate_cohesion_value():
	# Calculate base cohesion
	var base_cohesion = 50.0
	
	# Use the commander bonus function
	var commander_bonus = get_commander_bonus()
	
	# Formation bonus
	var formation_bonus = 0.0
	for i in range(soldiers.size()):
		var soldier = soldiers[i]
		if not soldier or not soldier.is_alive:
			continue
		
		var row = int(i / COLUMNS)
		var col = i % COLUMNS
		
		# Check neighbors
		var neighbors = get_neighbors(row, col)
		for neighbor_idx in neighbors:
			if neighbor_idx < soldiers.size():
				var neighbor = soldiers[neighbor_idx]
				if neighbor and neighbor.is_alive:
					# Basic adjacency bonus
					formation_bonus += 1.0
					
					# Nationality bonus/penalty
					if soldier.nationality == neighbor.nationality:
						formation_bonus += 0.5
					else:
						formation_bonus -= 0.25
	
	# Apply the 0.5 multiplier to formation bonus
	formation_bonus *= 0.5
	
	# Relationship bonus
	var relationship_bonus = 0.0
	if relationship_manager:
		relationship_bonus = relationship_manager.get_cohesion_bonus_for_formation()
	
	# Update current_cohesion with calculated value
	current_cohesion = base_cohesion + commander_bonus + formation_bonus + relationship_bonus
	
	return current_cohesion

func update_cohesion_display():
	if not cohesion_display:
		return
	
	# If in battle, use the battle manager's cohesion value
	if is_battle_active:
		var battle_screen = get_node_or_null("/root/BattleScreen")
		if battle_screen and battle_screen.battle_manager:
			current_cohesion = battle_screen.battle_manager.current_cohesion
	
	# Update text with formatted cohesion value
	cohesion_display.text = "Formation Cohesion: %.1f" % current_cohesion
	
	# Set color based on value
	var color = Color.WHITE
	if current_cohesion >= 100:
		color = Color(0, 0.8, 0)  # Bright green
	elif current_cohesion >= 80:
		color = Color(0.3, 0.8, 0.3)  # Green
	elif current_cohesion >= 60:
		color = Color(0.8, 0.8, 0)  # Yellow
	elif current_cohesion >= 40:
		color = Color(0.8, 0.4, 0)  # Orange
	else:
		color = Color(0.8, 0, 0)  # Red
		
	cohesion_display.add_theme_color_override("font_color", color)

func _calculate_and_update_cohesion():
	# Wait a frame to ensure everything is initialized
	await get_tree().process_frame
	
	# Calculate and update
	calculate_cohesion_value()
	update_cohesion_display()

# Helper function to get neighbors (if not already defined)
func get_neighbors(row: int, col: int) -> Array:
	var neighbors = []
	
	# Check all 8 directions
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			
			var new_row = row + dr
			var new_col = col + dc
			
			if new_row >= 0 and new_row < ROWS and new_col >= 0 and new_col < COLUMNS:
				neighbors.append(new_row * COLUMNS + new_col)
	
	return neighbors

# Helper function to find the commander
func get_commander() -> Soldier:
	for soldier in soldiers:
		if soldier and soldier.is_alive and soldier.soldier_name.begins_with("Commander "):
			return soldier
	return null

func _on_cohesion_details_pressed():
	# If in battle - show battle specific info
	if is_battle_active:
		# ... battle-specific code ...
		return
	
	# Define base cohesion value
	var base_cohesion = 50.0
	
	# Commander bonus
	var commander_bonus = get_commander_bonus()
	
	# Formation bonus - calculate adjacency and nationality effects
	var formation_bonus = 0.0
	for i in range(soldiers.size()):
		var soldier = soldiers[i]
		if not soldier or not soldier.is_alive:
			continue
		
		var row = int(i / COLUMNS)
		var col = i % COLUMNS
		
		# Check neighbors
		var neighbors = get_neighbors(row, col)
		for neighbor_idx in neighbors:
			if neighbor_idx < soldiers.size():
				var neighbor = soldiers[neighbor_idx]
				if neighbor and neighbor.is_alive:
					# Basic adjacency bonus
					formation_bonus += 1.0
					
					# Nationality bonus/penalty
					if soldier.nationality == neighbor.nationality:
						formation_bonus += 0.5
					else:
						formation_bonus -= 0.25
	
	# Apply the 0.5 multiplier to formation bonus
	formation_bonus *= 0.5
	
	# Relationship bonus
	var relationship_bonus = 0.0
	if relationship_manager:
		relationship_bonus = relationship_manager.get_cohesion_bonus_for_formation()
	
	# Calculate total cohesion
	var total_cohesion = base_cohesion + commander_bonus + formation_bonus + relationship_bonus
	
	# Create popup with details
	var popup = AcceptDialog.new()
	popup.title = "Cohesion Breakdown"
	
	var content = """
	Base Cohesion: 50.0
	Commander Bonus: %.1f
	Formation Bonus: %.1f
	Relationship Bonus: %.1f
	
	Total Cohesion: %.1f
	"""
	
	popup.dialog_text = content % [
		commander_bonus,
		formation_bonus,
		relationship_bonus,
		total_cohesion
	]
	
	# Set popup size
	popup.min_size = Vector2(300, 200)
	
	# Add to scene
	get_tree().root.add_child(popup)
	popup.popup_centered()
	
	# Update the display with the new value
	current_cohesion = total_cohesion
	update_cohesion_display()

func calculate_formation_bonus() -> float:
	var bonus = 0.0
	
	# Check adjacent soldiers
	for i in range(soldiers.size()):
		var soldier = soldiers[i]
		if not soldier or not soldier.is_alive:
			continue
		
		var row = i / COLUMNS
		var col = i % COLUMNS
		
		# Check neighbors
		var neighbors = get_neighbors(row, col)
		for neighbor_idx in neighbors:
			if neighbor_idx < soldiers.size():
				var neighbor = soldiers[neighbor_idx]
				if neighbor and neighbor.is_alive:
					# Basic adjacency bonus
					bonus += 1.0
					
					# Nationality bonus/penalty
					if soldier.nationality == neighbor.nationality:
						bonus += 0.5
					else:
						bonus -= 0.25
	
	return bonus

func setup_relationship_tooltip():
	# Create tooltip container
	relationship_tooltip = PanelContainer.new()
	relationship_tooltip.visible = false
	relationship_tooltip.name = "RelationshipTooltip"
	
	# Style the tooltip
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.95)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	relationship_tooltip.add_theme_stylebox_override("panel", style)
	
	# Add VBox for content
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	relationship_tooltip.add_child(vbox)
	
	# Add title label
	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Relationship with Soldier"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))  # Gold color
	vbox.add_child(title)
	
	# Add separator
	var separator = HSeparator.new()
	separator.name = "Separator"
	vbox.add_child(separator)
	
	# Add content container
	var content = VBoxContainer.new()
	content.name = "ContentContainer"
	vbox.add_child(content)
	
	# Add to a Canvas Layer to ensure it's visible
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # Very high layer number to be on top of everything
	canvas_layer.name = "TooltipLayer"
	add_child(canvas_layer)
	canvas_layer.add_child(relationship_tooltip)
	
	# Set minimum size to ensure visibility
	relationship_tooltip.custom_minimum_size = Vector2(250, 150)
	
	# Create hover timer
	hover_timer = Timer.new()
	hover_timer.one_shot = true
	hover_timer.wait_time = 0.3  # 300ms delay before showing tooltip
	hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(hover_timer)

func update_relationship_tooltip(soldier1: Soldier, soldier2: Soldier):
	if not relationship_tooltip or not relationship_manager:
		return
	
	# Get relationship value
	var relationship_value = 0
	if soldier2.id in soldier1.relationships:
		relationship_value = soldier1.relationships[soldier2.id]
	
	# Update title
	var title_label = null
	var vbox = relationship_tooltip.get_child(0)
	if vbox and vbox is VBoxContainer:
		title_label = vbox.get_node_or_null("TitleLabel")
	
	if title_label:
		title_label.text = "Relationship with " + soldier2.soldier_name
	
	# Get content container
	var content = null
	if vbox and vbox is VBoxContainer:
		content = vbox.get_node_or_null("ContentContainer")
	
	if not content:
		return
	
	# Clear previous content
	for child in content.get_children():
		child.queue_free()
	
	# Add relationship value
	var value_label = Label.new()
	value_label.text = "Value: " + str(relationship_value)
	if relationship_value > 0:
		value_label.add_theme_color_override("font_color", Color(0, 0.7, 0))  # Green
	elif relationship_value < 0:
		value_label.add_theme_color_override("font_color", Color(0.7, 0, 0))  # Red
	content.add_child(value_label)
	
	# Add relationship factors
	add_tooltip_section(content, "Nationality Factor:", get_nationality_factor(soldier1, soldier2))
	add_tooltip_section(content, "Trait Compatibility:", get_trait_compatibility(soldier1, soldier2))
	
	# Add events together if any
	var events_together = get_events_together(soldier1.id, soldier2.id)
	if events_together > 0:
		add_tooltip_section(content, "Shared Events:", events_together)
	
	# Add proximity (position) effects
	add_tooltip_section(content, "Formation Proximity:", get_proximity_effect(soldier1, soldier2))
	
	# Add command effects if one is commander
	if soldier1.soldier_name.begins_with("Commander ") or soldier2.soldier_name.begins_with("Commander "):
		add_tooltip_section(content, "Command Dynamics:", get_command_effect(soldier1, soldier2))
	
	# Ensure the tooltip content is visible
	relationship_tooltip.visible = true

func add_tooltip_section(container: VBoxContainer, title: String, value: float):
	if value == 0:
		return  # Don't add sections with zero effect
	
	var hbox = HBoxContainer.new()
	
	var title_label = Label.new()
	title_label.text = title
	title_label.custom_minimum_size.x = 160
	hbox.add_child(title_label)
	
	var value_label = Label.new()
	var prefix = "+" if value > 0 else ""
	value_label.text = prefix + str(value)
	
	if value > 0:
		value_label.add_theme_color_override("font_color", Color(0, 0.7, 0))  # Green
	else:
		value_label.add_theme_color_override("font_color", Color(0.7, 0, 0))  # Red
	
	hbox.add_child(value_label)
	container.add_child(hbox)

func get_nationality_factor(soldier1: Soldier, soldier2: Soldier) -> float:
	if soldier1.nationality == soldier2.nationality:
		return 20.0
	
	# Check compatibility matrix for other nationality relationships
	if relationship_manager and relationship_manager.compatibility_matrix.has("nationalities"):
		var nationality_key = soldier1.nationality + "_" + soldier2.nationality
		var reverse_key = soldier2.nationality + "_" + soldier1.nationality
		
		if nationality_key in relationship_manager.compatibility_matrix["nationalities"]:
			return relationship_manager.compatibility_matrix["nationalities"][nationality_key]
		elif reverse_key in relationship_manager.compatibility_matrix["nationalities"]:
			return relationship_manager.compatibility_matrix["nationalities"][reverse_key]
	
	return -5.0  # Default negative value for different nationalities

func get_trait_compatibility(soldier1: Soldier, soldier2: Soldier) -> float:
	var compatibility_score = 0.0
	
	if not relationship_manager or not relationship_manager.compatibility_matrix.has("traits"):
		return 0.0
	
	# Check trait compatibility
	for current_trait1 in soldier1.traits:
		for current_trait2 in soldier2.traits:
			var trait_key = current_trait1.trait_name + "_" + current_trait2.trait_name
			var reverse_key = current_trait2.trait_name + "_" + current_trait1.trait_name
			
			if trait_key in relationship_manager.compatibility_matrix["traits"]:
				compatibility_score += relationship_manager.compatibility_matrix["traits"][trait_key]
			elif reverse_key in relationship_manager.compatibility_matrix["traits"]:
				compatibility_score += relationship_manager.compatibility_matrix["traits"][reverse_key]
	
	return compatibility_score

func get_events_together(soldier1_id: String, soldier2_id: String) -> float:
	# Check for shared events in relationship manager
	if relationship_manager and "event_history" in relationship_manager:
		var key = relationship_manager.get_relationship_key(soldier1_id, soldier2_id)
		if key in relationship_manager.event_history:
			return relationship_manager.event_history[key] * relationship_manager.SHARED_EVENT_MODIFIER
	
	return 0.0

func get_proximity_effect(soldier1: Soldier, soldier2: Soldier) -> float:
	# Calculate proximity effect based on positions
	var pos1 = get_soldier_position(soldier1)
	var pos2 = get_soldier_position(soldier2)
	
	if pos1 < 0 or pos2 < 0:
		return 0.0
	
	var row1 = pos1 / COLUMNS
	var col1 = pos1 % COLUMNS
	var row2 = pos2 / COLUMNS
	var col2 = pos2 % COLUMNS
	
	# Calculate distance
	var distance = abs(row1 - row2) + abs(col1 - col2)
	
	if distance <= 1:
		return 5.0  # Adjacent
	elif distance <= 2:
		return 2.0  # Near
	else:
		return 0.0  # Far apart

func get_command_effect(soldier1: Soldier, soldier2: Soldier) -> float:
	# Check if one is commander
	var commander: Soldier
	var subordinate: Soldier
	
	if soldier1.soldier_name.begins_with("Commander "):
		commander = soldier1
		subordinate = soldier2
	elif soldier2.soldier_name.begins_with("Commander "):
		commander = soldier2
		subordinate = soldier1
	else:
		return 0.0
	
	# Calculate command effect
	var stats_difference = subordinate.get_total_stats() - commander.get_total_stats()
	
	if stats_difference > relationship_manager.COMMAND_RESENTMENT_THRESHOLD:
		# Check for ambitious traits
		for current_trait in subordinate.traits:
			if current_trait.trait_name == "Ambitious" or current_trait.trait_name == "Prideful":
				return -10.0  # Strong resentment
		return -5.0  # Mild resentment
	else:
		# Positive command relationship
		return 5.0

func show_relationship_tooltip(position: Vector2):
	if relationship_tooltip:
		# Position near the mouse but not under it
		relationship_tooltip.global_position = position + Vector2(20, 10)
		
		# Ensure it's not going off-screen
		var viewport_size = get_viewport_rect().size
		var tooltip_size = relationship_tooltip.size
		
		if relationship_tooltip.global_position.x + tooltip_size.x > viewport_size.x:
			relationship_tooltip.global_position.x = viewport_size.x - tooltip_size.x - 10
			
		if relationship_tooltip.global_position.y + tooltip_size.y > viewport_size.y:
			relationship_tooltip.global_position.y = viewport_size.y - tooltip_size.y - 10
			
		# Make sure it's visible
		relationship_tooltip.visible = true

func hide_relationship_tooltip():
	if relationship_tooltip:
		relationship_tooltip.visible = false
		current_tooltip_soldier = null
		hover_timer.stop()

func _on_cohesion_changed(new_cohesion):
	# Update our local cohesion value
	current_cohesion = new_cohesion
	
	# Force update the display with the new value from battle manager
	if cohesion_display:
		cohesion_display.text = "Formation Cohesion: %.1f" % current_cohesion
		
		# Set color based on value
		var color = Color.WHITE
		if current_cohesion >= 100:
			color = Color(0, 0.8, 0)  # Bright green for excellent cohesion
		elif current_cohesion >= 80:
			color = Color(0.3, 0.8, 0.3)  # Green for good cohesion
		elif current_cohesion >= 60:
			color = Color(0.8, 0.8, 0)  # Yellow for moderate cohesion
		elif current_cohesion >= 40:
			color = Color(0.8, 0.4, 0)  # Orange for poor cohesion
		else:
			color = Color(0.8, 0, 0)  # Red for terrible cohesion
			
		cohesion_display.add_theme_color_override("font_color", color)
	
	print("Formation cohesion updated to: ", current_cohesion)

func get_commander_bonus() -> float:
	var commander_bonus = 0.0
	var commander = get_commander()
	if commander:
		commander_bonus = commander.logos * 0.5
		
		# Reduced bonus for acting commander
		if commander.soldier_name.begins_with("Acting Commander ") or commander.has_meta("temp_commander"):
			commander_bonus *= 0.5  # Half effectiveness
	
	return commander_bonus

func _on_casualties_occurred(dead_soldiers_array):
	# If we're displaying relationship values, update them
	if current_tab_is_relationships and selected_slot:
		var index = selected_slot.get_meta("index")
		if index < soldiers.size():
			var selected_soldier = soldiers[index]
			display_relationship_values(selected_soldier, true)

	# Only show tooltip if we're still hovering over the same soldier
	if currently_hovering and current_hover_soldier and selected_slot:
		var selected_index = selected_slot.get_meta("index")
		if selected_index < soldiers.size():
			var selected_soldier = soldiers[selected_index]
			
			if selected_soldier:
				# Update and show tooltip
				update_relationship_tooltip(selected_soldier, current_hover_soldier)
				show_relationship_tooltip(get_global_mouse_position())
