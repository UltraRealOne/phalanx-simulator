extends Node

# Singleton reference
static var instance: EventManager

# Event data
var all_events: Dictionary = {}  # event_id -> GameEvent
var event_history: Array = []  # Track triggered events
var pending_events: Array = []  # Events ready to trigger

# Game state
var current_turn: int = 0
var current_phase: String = "peaceful"  # peaceful, battle
var soldiers_reference: Array = []

# Event popup reference
var current_popup: Control = null

# Signals
signal event_completed(event, involved_soldiers, choice_index)
signal trait_expressed(soldier: Soldier, trait_name: String)

func _ready():
	load_all_events()

func load_all_events():
	# Load test events first
	load_events_from_file("res://data/events/test_events.json")
	# Will add more files later

func load_events_from_file(file_path: String):
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to load events from: " + file_path)
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse events JSON: " + file_path)
		return
	
	var events_data = json.data
	for event_data in events_data:
		var event = create_event_from_data(event_data)
		all_events[event.event_id] = event

func create_event_from_data(data: Dictionary) -> GameEvent:
	var event = GameEvent.new()
	
	event.event_id = data.get("id", "")
	event.event_name = data.get("name", "")
	event.event_type = data.get("type", "generic")
	event.event_text = data.get("text", "")
	event.trigger_tags = data.get("trigger_tags", [])
	event.trigger_chance = data.get("trigger_chance", 1.0)
	event.can_repeat = data.get("can_repeat", false)
	event.requires_soldiers = data.get("requires_soldiers", 1)
	event.soldier_filters = data.get("soldier_filters", [])
	
	# Parse choices
	var choices_data = data.get("choices", [])
	for choice_data in choices_data:
		var choice = EventChoice.new()
		choice.choice_text = choice_data.get("text", "")
		choice.choice_id = choice_data.get("id", "")
		
		# Parse consequences
		var consequences_data = choice_data.get("consequences", [])
		for cons_data in consequences_data:
			var consequence = create_consequence_from_data(cons_data)
			choice.consequences.append(consequence)
		
		event.choices.append(choice)
	
	return event

func create_consequence_from_data(data: Dictionary) -> EventConsequence:
	var consequence = EventConsequence.new()
	
	var type_string = data.get("type", "")
	match type_string:
		"stat_change":
			consequence.type = EventConsequence.ConsequenceType.STAT_CHANGE
		"add_trait":
			consequence.type = EventConsequence.ConsequenceType.ADD_TRAIT
		"remove_trait":
			consequence.type = EventConsequence.ConsequenceType.REMOVE_TRAIT
		"relationship_change":
			consequence.type = EventConsequence.ConsequenceType.RELATIONSHIP_CHANGE
		"death":
			consequence.type = EventConsequence.ConsequenceType.DEATH
		"wound":
			consequence.type = EventConsequence.ConsequenceType.WOUND
		"heal":
			consequence.type = EventConsequence.ConsequenceType.HEAL
		"form_friendship":
			consequence.type = EventConsequence.ConsequenceType.FORM_FRIENDSHIP
		"form_rivalry":
			consequence.type = EventConsequence.ConsequenceType.FORM_RIVALRY
	
	consequence.target = data.get("target", "self")
	consequence.value = data.get("value", 0)
	consequence.stat_name = data.get("stat", "")
	consequence.trait_name = data.get("trait", "")
	consequence.text_override = data.get("text", "")
	
	return consequence

func check_for_events(phase: String = ""):
	current_phase = phase if phase != "" else current_phase
	pending_events.clear()
	
	# Check all events for triggers
	for event_id in all_events:
		var event = all_events[event_id]
		
		# Check phase tag
		if current_phase in event.trigger_tags or "any" in event.trigger_tags:
			if event.can_trigger(current_turn, soldiers_reference):
				pending_events.append(event)
	
	# Sort by priority if needed
	# Trigger first event
	if pending_events.size() > 0:
		var random_index = randi() % pending_events.size()
		trigger_event(pending_events[random_index])

func trigger_specific_event(event_id: String):
	if event_id in all_events:
		var event = all_events[event_id]
		trigger_event(event)
	else:
		print("Event not found: " + event_id)

func trigger_event(event: GameEvent, involved_soldiers: Array = []):
	# Select soldiers if not provided
	if involved_soldiers.is_empty():
		involved_soldiers = select_soldiers_for_event(event)
	
	# Show popup
	var event_popup_scene = load("res://scenes/ui/event_popup.tscn")
	current_popup = event_popup_scene.instantiate()
	get_tree().root.add_child(current_popup)
	current_popup.setup_event(event, involved_soldiers)
	current_popup.choice_made.connect(_on_choice_made.bind(event, involved_soldiers))
	
	# Mark event as triggered
	event.trigger_event()
	event_history.append(event.event_id)

func select_soldiers_for_event(event: GameEvent) -> Array:
	var valid_soldiers = event.filter_soldiers(soldiers_reference)
	var selected = []
	
	# Simple random selection for now
	for i in range(event.requires_soldiers):
		if valid_soldiers.size() > 0:
			var rand_index = randi() % valid_soldiers.size()
			var selected_soldier = valid_soldiers[rand_index]
			
			# Find soldier's position in the grid
			var position_index = soldiers_reference.find(selected_soldier)
			if position_index != -1:
				# Store position in soldier metadata temporarily
				selected_soldier.set_meta("grid_position", position_index)
			
			selected.append(selected_soldier)
			valid_soldiers.remove_at(rand_index)
	
	return selected

func _on_choice_made(choice_index: int, event: GameEvent, soldiers: Array):
	if choice_index >= event.choices.size():
		return
		
	var choice = event.choices[choice_index]
	
	# Check for expressed trait
	if "expressed_trait" in choice and choice.expressed_trait != "":
		var soldier = soldiers[0] if soldiers.size() > 0 else null
		if soldier:
			trait_expressed.emit(soldier, choice.expressed_trait)
	
	# Store affected soldiers to update their displays
	var affected_soldiers = []
	
	# Apply consequences
	for consequence in choice.consequences:
		# Determine target soldiers
		var target_soldiers = []
		
		match consequence.target:
			"self":
				if soldiers.size() > 0:
					target_soldiers = [soldiers[0]]
			"other":
				if soldiers.size() > 1:
					target_soldiers = [soldiers[1]]
			"all":
				target_soldiers = soldiers
			"random":
				if soldiers.size() > 0:
					target_soldiers = [soldiers[randi() % soldiers.size()]]
		
		# Apply to each target
		for soldier in target_soldiers:
			# Special handling for ADD_TRAIT
			if consequence.type == EventConsequence.ConsequenceType.ADD_TRAIT:
				var new_trait = get_trait_by_name(consequence.trait_name)
				if new_trait:
					soldier.add_trait(new_trait)
			else:
				consequence.apply_to_soldier(soldier)
				
			# Track affected soldiers
			if soldier not in affected_soldiers:
				affected_soldiers.append(soldier)
	
	# Check for next event
	if choice.next_event_id != "":
		var next_event = all_events.get(choice.next_event_id)
		if next_event:
			trigger_event(next_event, soldiers)
			
	# Update all affected soldiers' displays
	for soldier in affected_soldiers:
		var position_index = soldier.get_meta("grid_position", -1)
		if position_index != -1:
			# Call update on formation grid
			var formation_grid = get_node_or_null("/root/Main/FormationGrid")
			if formation_grid:
				formation_grid.update_soldier_at_position(position_index, soldier)
	
	# Emit completed signal
	event_completed.emit(event, soldiers, choice_index)

func set_soldiers_reference(soldiers: Array):
	soldiers_reference = soldiers

func get_trait_by_name(trait_name: String) -> Trait:
	# Load traits data and find matching trait
	var traits_file = FileAccess.open("res://data/traits.json", FileAccess.READ)
	if traits_file:
		var json_string = traits_file.get_as_text()
		traits_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var traits_data = json.data
			for trait_data in traits_data:
				if trait_data["name"] == trait_name:
					var new_trait = Trait.new()
					new_trait.trait_name = trait_data["name"]
					new_trait.description = trait_data["description"]
					new_trait.type = trait_data["type"]
					new_trait.category = trait_data["category"]
					
					if "modifiers" in trait_data:
						var modifiers = trait_data["modifiers"]
						new_trait.health_modifier = modifiers.get("health", 0)
						new_trait.morale_modifier = modifiers.get("morale", 0)
						new_trait.andreia_modifier = modifiers.get("andreia", 0)
						new_trait.logos_modifier = modifiers.get("logos", 0)
					
					return new_trait
	return null

func queue_event_with_tag(tag: String, involved_soldiers: Array = []):
	# Find events with the specific tag
	var matching_events = []
	
	for event_id in all_events:
		var event = all_events[event_id]
		if tag in event.trigger_tags:
			# Check if event is valid for these soldiers
			if involved_soldiers.is_empty() or event.is_valid_for_soldiers(involved_soldiers):
				matching_events.append(event)
	
	# If we found any matching events, trigger a random one
	if matching_events.size() > 0:
		var chosen_event = matching_events[randi() % matching_events.size()]
		trigger_event(chosen_event, involved_soldiers)
		return true
	
	return false
