extends Control

@onready var battle_name_label = $Panel/VBoxContainer/BattleNameLabel
@onready var timer_label = $Panel/VBoxContainer/TimerLabel
@onready var casualty_label = $Panel/VBoxContainer/CasualtyLabel
@onready var cohesion_bar = $Panel/VBoxContainer/CohesionBar
@onready var progress_bar = $Panel/VBoxContainer/BattleProgressBar
@onready var event_log = $Panel/VBoxContainer/EventLog

var battle_manager: BattleManager
var formation_reference: Node2D
var last_casualty_text: String = ""  # Add this at the top of battle_screen.gd

func setup_battle(battle_data: Dictionary, formation: Node2D, soldiers: Array):
	formation_reference = formation
	
	# Create battle manager
	battle_manager = BattleManager.new()
	add_child(battle_manager)
	
	# Connect signals
	battle_manager.battle_started.connect(_on_battle_started)
	battle_manager.casualties_occurred.connect(_on_casualties_occurred)
	battle_manager.battle_ended.connect(_on_battle_ended)
	battle_manager.replacement_needed.connect(_on_replacement_needed)
	battle_manager.expected_casualties_updated.connect(update_casualty_display)
	battle_manager.funeral_needed.connect(_on_funeral_needed)
	
	# Setup battle
	battle_manager.setup_battle(battle_data, formation, soldiers)
	
	# Update UI
	battle_name_label.text = battle_data.get("name", "Unknown Battle")
	update_casualty_display()
	update_cohesion_display()

func _on_replacement_needed(replacement_data: Array):
	var dead_position = replacement_data[0]
	var available_positions = replacement_data[1]
	
	# Create replacement panel
	var replacement_panel = preload("res://scenes/ui/replacement_panel.tscn").instantiate()
	get_tree().root.add_child(replacement_panel)
	
	# Setup and connect - pass battle_manager reference
	replacement_panel.setup_replacement(dead_position, available_positions, battle_manager)
	replacement_panel.replacement_selected.connect(_on_replacement_selected)

func _on_replacement_selected(dead_position: int, replacement_position: int):
	# Store the replacement soldier BEFORE moving
	var replacement_soldier = battle_manager.soldiers_reference[replacement_position]
	
	# Apply the replacement in battle manager
	battle_manager.apply_replacement(dead_position, replacement_position)
	
	# Update formation display - use battle_manager's array!
	if formation_reference:
		# Manually sync both positions
		formation_reference.soldiers[dead_position] = replacement_soldier
		formation_reference.soldiers[replacement_position] = null
		
		# Update displays
		formation_reference.update_slot_display(dead_position, replacement_soldier)
		formation_reference.update_slot_display(replacement_position, null)
	
	# Update UI
	update_cohesion_display()

func _ready():
	set_process(false)
	# Make sure battle screen appears on top but doesn't block the grid
	self.z_index = 5
	
	# Lower the panel's z-index so text appears on top
	if $Panel:
		$Panel.z_index = -1
		$Panel.show_behind_parent = true

func start_battle():
	battle_manager.start_battle()
	set_process(true)

func _process(delta):
	if battle_manager and battle_manager.is_battle_active:
		battle_manager.update_battle(delta)
		update_timer_display()
		update_progress_bar()
		update_casualty_display()  # Update this every frame
		update_cohesion_display()  # And this too

func update_timer_display():
	var time_remaining = battle_manager.battle_duration - battle_manager.current_time
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	timer_label.text = "Time: %02d:%02d" % [minutes, seconds]

func update_casualty_display():
	if battle_manager:
		# Direct access to the property
		var expected_display = battle_manager.dynamic_expected_casualties
		
		var new_text = "Casualties: %d / %d expected" % [
			battle_manager.actual_casualties,
			expected_display
		]
		
		# Only update if text actually changed
		if new_text != last_casualty_text:
			last_casualty_text = new_text
			casualty_label.text = new_text
			
			# Add visual indicator if expectations have increased
			if expected_display > battle_manager.expected_casualties:
				casualty_label.add_theme_color_override("font_color", Color.ORANGE)
			else:
				casualty_label.add_theme_color_override("font_color", Color.WHITE)

func update_cohesion_display():
	if battle_manager:
		# Use starting cohesion as max, not current
		cohesion_bar.max_value = battle_manager.starting_cohesion
		cohesion_bar.value = battle_manager.current_cohesion
		
		# Add text to show actual cohesion value
		cohesion_bar.show_percentage = false
		var cohesion_text = "Cohesion: %.1f / %.1f" % [battle_manager.current_cohesion, battle_manager.starting_cohesion]
		
		# Color based on cohesion level
		if battle_manager.current_cohesion > battle_manager.starting_cohesion * 0.7:
			cohesion_bar.modulate = Color.GREEN
		elif battle_manager.current_cohesion > battle_manager.starting_cohesion * 0.4:
			cohesion_bar.modulate = Color.YELLOW
		else:
			cohesion_bar.modulate = Color.RED

func update_progress_bar():
	progress_bar.max_value = battle_manager.battle_duration
	progress_bar.value = battle_manager.current_time

func _on_battle_started():
	add_event_log("Battle has begun!")

func _on_casualties_occurred(dead_soldiers: Array):
	for soldier in dead_soldiers:
		add_event_log("%s has fallen in battle!" % soldier.soldier_name)
		
		# Update the formation grid display
		if formation_reference and formation_reference.has_method("update_soldier_death"):
			var position = soldier.get_meta("last_position", -1)
			if position >= 0:
				formation_reference.update_soldier_death(position)
				
	update_casualty_display()
	update_cohesion_display()

func _on_battle_ended():
	set_process(false)
	add_event_log("Battle has ended.")
	
	# Show statistics
	var stats = battle_manager.get_battle_statistics()
	add_event_log("Final casualties: %d" % stats.actual_casualties)
	add_event_log("Survival rate: %.1f%%" % (stats.survival_rate * 100))

func add_event_log(text: String):
	if not is_instance_valid(event_log) or not event_log.is_inside_tree():
		return
		
	var time_stamp = Time.get_time_string_from_system()
	event_log.append_text("[%s] %s\n" % [time_stamp, text])

func _on_funeral_needed(fallen: Array):
	print("Funeral needed for %d soldiers" % fallen.size())
	
	# Convert to typed arrays
	var fallen_soldiers: Array[Soldier] = []
	for soldier in fallen:
		fallen_soldiers.append(soldier as Soldier)
	
	# Get surviving soldiers
	var survivors: Array[Soldier] = []
	for soldier in battle_manager.soldiers_reference:
		if soldier and soldier.is_alive:
			survivors.append(soldier as Soldier)
	
	# Create funeral screen
	var funeral_screen = preload("res://scenes/funeral_screen.tscn").instantiate()
	get_tree().root.add_child(funeral_screen)
	
	# Setup and connect
	funeral_screen.setup_funeral(fallen_soldiers, survivors)
	
	# Connect signals - make sure to connect begin_ceremony signal
	funeral_screen.begin_ceremony.connect(_on_funeral_begin_ceremony)
	funeral_screen.funeral_completed.connect(_on_funeral_completed)

func _on_funeral_begin_ceremony():
	# Hide the battle screen when ceremony begins
	visible = false
	# You could also use queue_free() to remove it completely,
	# but then you would need to implement a way to handle post-funeral logic differently

func _on_funeral_completed():
	print("Funeral completed, checking for replacements")
	
	# If you used visible = false earlier, make self visible again if needed
	# visible = true
	
	# Now check for replacements after funeral
	var empty_slots = []
	for i in range(battle_manager.soldiers_reference.size()):
		var soldier = battle_manager.soldiers_reference[i]
		if not soldier or not soldier.is_alive:
			empty_slots.append(i)
	
	if empty_slots.size() > 0:
		print("Need replacements for slots: ", empty_slots)
		# TODO: Handle post-battle replacements
