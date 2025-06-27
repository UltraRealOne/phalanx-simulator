extends Node
class_name RelationshipManager

# Add this at the top of the file
const RelationshipGenerator = preload("res://scripts/relationship/relationship_generator.gd")

signal relationship_changed(soldier1_id: String, soldier2_id: String, value: int)
signal significant_relationship_formed(soldier1: Soldier, soldier2: Soldier, is_positive: bool)
signal trait_expressed(soldier: Soldier, trait_name: String)

# Constants
const RELATIONSHIP_MIN: int = -100
const RELATIONSHIP_MAX: int = 100
const FRIEND_THRESHOLD: int = 50
const RIVAL_THRESHOLD: int = -50
const PROXIMITY_MODIFIER: float = 0.2 # Per turn
const SHARED_EVENT_MODIFIER: float = 5.0
const SHARED_BATTLE_MODIFIER: float = 3.0
const CULTURAL_FRICTION_CHANCE: float = 0.15 # 15% chance per turn
const CULTURAL_FRICTION_VALUE: int = -10
const COMMAND_RESENTMENT_THRESHOLD: int = 5
const COMMAND_RESENTMENT_CHANCE: float = 0.25 # 25% chance per turn
const COMMAND_RESENTMENT_VALUE: int = -5
const ATTRIBUTE_TENSION_VALUE: int = -2 # -2 for opposing attributes
const MAX_FRIENDS: int = 4
const MAX_RIVALS: int = 2

# References
var formation_grid: Node2D
var soldiers_reference: Array[Soldier] = []
var compatibility_matrix: Dictionary = {}
var opposite_traits: Dictionary = {}

# Tracking
var turn_counter: int = 0
var formation_history: Array = [] # Track position changes
var event_history: Dictionary = {} # Track event participation

func _ready():
	load_compatibility_data()
	setup_opposite_traits()

func load_compatibility_data():
	var file = FileAccess.open("res://data/relationships/compatibility_matrix.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			compatibility_matrix = json.data

func setup_opposite_traits():
	# Define opposite traits for trait reaction system
	opposite_traits = {
		"Brave": ["Coward", "Timid"],
		"Coward": ["Brave", "Battle Hardened"],
		"Disciplined": ["Unruly", "Sloppy"],
		"Methodical": ["Unruly", "Sloppy"],
		"Adaptable": ["Rigid"],
		"Rigid": ["Adaptable"],
		"Loyal": ["Traitorous"],
		"Inspiring": ["Taciturn"],
		"Iron Body": ["Frail", "Sickly"],
		"Stoic": ["Moody", "Unstable"]
	}

func initialize_relationships(soldiers: Array[Soldier]):
	soldiers_reference = soldiers
	
	# Generate initial relationships
	var relationship_generator = RelationshipGenerator.new()
	relationship_generator.generate_initial_relationships(soldiers, compatibility_matrix)
	
	# Connect events to track changes
	var event_manager = get_node_or_null("/root/EventManager")
	if event_manager:
		# Check if the signal exists - use a different approach
		if event_manager.has_signal("event_completed"):
			event_manager.event_completed.connect(_on_event_completed)
		
		# Check for trait_expressed signal
		if event_manager.has_signal("trait_expressed"):
			event_manager.trait_expressed.connect(_on_trait_expressed)
	else:
		print("Warning: EventManager not found")

func update_relationships(delta: float):
	# This would be called periodically (e.g., after battles, events, turns)
	turn_counter += 1
	
	# Update proximity effects
	update_proximity_relationships()
	
	# Update trait compatibility effects
	update_trait_compatibility()
	
	# Update cultural friction
	update_cultural_friction()
	
	# Update command resentment
	update_command_resentment()
	
	# Check for significant relationships
	check_significant_relationships()

func update_proximity_relationships():
	# Get current formation positions
	var positions = []
	for i in range(soldiers_reference.size()):
		var soldier = soldiers_reference[i]
		if soldier and soldier.is_alive:
			positions.append(formation_grid.get_soldier_position(soldier))
		else:
			positions.append(-1) # Invalid position for dead soldiers
	
	# Keep a history of positions
	formation_history.append(positions)
	if formation_history.size() > 10: # Keep last 10 turns
		formation_history.pop_front()
	
	# Calculate how long soldiers have been adjacent
	var adjacency_duration = {}
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			var relationship_key = get_relationship_key(soldier1.id, soldier2.id)
			var adjacent_turns = count_adjacent_turns(i, j)
			adjacency_duration[relationship_key] = adjacent_turns
	
	# Apply relationship changes based on adjacency
	for relationship_key in adjacency_duration:
		var adjacent_turns = adjacency_duration[relationship_key]
		if adjacent_turns > 0:
			var ids = relationship_key.split("_")
			if ids.size() == 2:
				# More turns together = stronger effect
				var modifier = PROXIMITY_MODIFIER * sqrt(adjacent_turns)
				modify_relationship(ids[0], ids[1], modifier)

func count_adjacent_turns(index1: int, index2: int) -> int:
	var adjacent_count = 0
	for positions in formation_history:
		if index1 < positions.size() and index2 < positions.size():
			var pos1 = positions[index1]
			var pos2 = positions[index2]
			if pos1 >= 0 and pos2 >= 0 and are_positions_adjacent(pos1, pos2):
				adjacent_count += 1
	return adjacent_count

func are_positions_adjacent(pos1: int, pos2: int) -> bool:
	if pos1 < 0 or pos2 < 0:
		return false
	
	var row1 = pos1 / 8
	var col1 = pos1 % 8
	var row2 = pos2 / 8
	var col2 = pos2 % 8
	
	# Adjacent if difference is at most 1 in both row and column
	return abs(row1 - row2) <= 1 and abs(col1 - col2) <= 1

func update_trait_compatibility():
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			var compatibility = calculate_trait_compatibility(soldier1, soldier2)
			if compatibility != 0:
				modify_relationship(soldier1.id, soldier2.id, compatibility * 0.1)

func calculate_trait_compatibility(soldier1: Soldier, soldier2: Soldier) -> float:
	var compatibility_score = 0.0
	
	# Nationality compatibility
	if soldier1.nationality == soldier2.nationality:
		compatibility_score += 1.0
	else:
		var nationality_key = soldier1.nationality + "_" + soldier2.nationality
		var reverse_key = soldier2.nationality + "_" + soldier1.nationality
		
		if nationality_key in compatibility_matrix.get("nationalities", {}):
			compatibility_score += compatibility_matrix["nationalities"][nationality_key]
		elif reverse_key in compatibility_matrix.get("nationalities", {}):
			compatibility_score += compatibility_matrix["nationalities"][reverse_key]
		else:
			compatibility_score -= 0.5
	
	# Trait compatibility
	for current_trait1 in soldier1.traits:
		for current_trait2 in soldier2.traits:
			var trait_key = current_trait1.trait_name + "_" + current_trait2.trait_name
			var reverse_key = current_trait2.trait_name + "_" + current_trait1.trait_name
			
			if trait_key in compatibility_matrix.get("traits", {}):
				compatibility_score += compatibility_matrix["traits"][trait_key]
			elif reverse_key in compatibility_matrix.get("traits", {}):
				compatibility_score += compatibility_matrix["traits"][reverse_key]
	
	# Attribute tension between Andreia and Logos
	# This produces a natural tension between physical-focused and mental-focused soldiers
	if soldier1.andreia - soldier1.logos > 5 and soldier2.logos - soldier2.andreia > 5:
		compatibility_score -= 2.0 # Clash between physical-focused and mental-focused
	elif soldier1.logos - soldier1.andreia > 5 and soldier2.andreia - soldier2.logos > 5:
		compatibility_score -= 2.0 # Same clash, opposite direction
	
	return compatibility_score

func update_cultural_friction():
	# Check for cultural friction between different nationalities
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			# Skip same nationality
			if soldier1.nationality == soldier2.nationality:
				continue
			
			# Check if soldiers are adjacent
			var positions = []
			for idx in range(soldiers_reference.size()):
				if soldiers_reference[idx] and soldiers_reference[idx].is_alive:
					positions.append(formation_grid.get_soldier_position(soldiers_reference[idx]))
				else:
					positions.append(-1)
					
			if are_positions_adjacent(positions[i], positions[j]):
				# Random chance for friction
				if randf() < CULTURAL_FRICTION_CHANCE:
					# Apply friction penalty
					modify_relationship(soldier1.id, soldier2.id, CULTURAL_FRICTION_VALUE)
					
					# Possibly trigger cultural tension event
					var event_manager = get_node_or_null("/root/EventManager")
					if event_manager and event_manager.has_method("queue_event_with_tag"):
						event_manager.queue_event_with_tag("cultural_tension", [soldier1, soldier2])

func update_command_resentment():
	# Get current commander
	var commander = null
	for soldier in soldiers_reference:
		if soldier and soldier.is_alive and soldier.soldier_name.begins_with("Commander "):
			commander = soldier
			break
	
	if not commander:
		return
	
	# Check each soldier for potential resentment
	for soldier in soldiers_reference:
		if not soldier or not soldier.is_alive or soldier.id == commander.id:
			continue
		
		# Calculate total stats difference
		var commander_stats = commander.get_total_stats()
		var soldier_stats = soldier.get_total_stats()
		
		# Check if soldier has significantly better stats
		if soldier_stats > commander_stats + COMMAND_RESENTMENT_THRESHOLD:
			# Random chance for resentment
			if randf() < COMMAND_RESENTMENT_CHANCE:
				# Apply resentment penalty
				modify_relationship(soldier.id, commander.id, COMMAND_RESENTMENT_VALUE)
				
				# Check for ambition traits to increase resentment
				var has_ambition_trait = false
				for current_trait in soldier.traits:
					if current_trait.trait_name == "Ambitious" or current_trait.trait_name == "Prideful":
						has_ambition_trait = true
						modify_relationship(soldier.id, commander.id, COMMAND_RESENTMENT_VALUE)
						break
				
				# Possibly trigger resentment event
				var event_manager = get_node_or_null("/root/EventManager")
				if event_manager and event_manager.has_method("queue_event_with_tag") and has_ambition_trait:
					event_manager.queue_event_with_tag("command_resentment", [soldier, commander])

func modify_relationship(soldier1_id: String, soldier2_id: String, value: float):
	if soldier1_id == soldier2_id:
		return
	
	# Find the soldiers
	var soldier1 = find_soldier_by_id(soldier1_id)
	var soldier2 = find_soldier_by_id(soldier2_id)
	
	if not soldier1 or not soldier2:
		return
	
	# Update relationships
	var current_value = 0
	if soldier2_id in soldier1.relationships:
		current_value = soldier1.relationships[soldier2_id]
	
	var new_value = clamp(current_value + value, RELATIONSHIP_MIN, RELATIONSHIP_MAX)
	
	# Only update if there's an actual change
	if new_value != current_value:
		soldier1.relationships[soldier2_id] = new_value
		soldier2.relationships[soldier1_id] = new_value # Mirror the relationship
		
		# Emit signal
		relationship_changed.emit(soldier1_id, soldier2_id, new_value)

func check_significant_relationships():
	# Check for threshold crossings for friend/rival status
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			if soldier2.id in soldier1.relationships:
				var value = soldier1.relationships[soldier2.id]
				
				# Check for crossing the friendship threshold
				if value >= FRIEND_THRESHOLD and value - 1 < FRIEND_THRESHOLD:
					# Check if both soldiers have room for new friends
					var s1_friends = count_relationships(soldier1, true)
					var s2_friends = count_relationships(soldier2, true)
					
					if s1_friends >= MAX_FRIENDS or s2_friends >= MAX_FRIENDS:
						# Reduce relationship if limit reached
						modify_relationship(soldier1.id, soldier2.id, -5)
						print("Friend limit reached, reducing relationship between " + 
							  soldier1.soldier_name + " and " + soldier2.soldier_name)
					else:
						# Signal for event but don't automatically form relationship
						var event_manager = get_node_or_null("/root/EventManager")
						if event_manager and event_manager.has_method("queue_event_with_tag"):
							event_manager.queue_event_with_tag("friendship_potential", [soldier1, soldier2])
				
				# Check for crossing the rivalry threshold
				elif value <= RIVAL_THRESHOLD and value + 1 > RIVAL_THRESHOLD:
					# Check if both soldiers have room for new rivals
					var s1_rivals = count_relationships(soldier1, false)
					var s2_rivals = count_relationships(soldier2, false)
					
					if s1_rivals >= MAX_RIVALS or s2_rivals >= MAX_RIVALS:
						# Increase relationship if limit reached
						modify_relationship(soldier1.id, soldier2.id, 5)
						print("Rival limit reached, increasing relationship between " + 
							  soldier1.soldier_name + " and " + soldier2.soldier_name)
					else:
						# Signal for event but don't automatically form rivalry
						var event_manager = get_node_or_null("/root/EventManager")
						if event_manager and event_manager.has_method("queue_event_with_tag"):
							event_manager.queue_event_with_tag("rivalry_potential", [soldier1, soldier2])

func count_relationships(soldier: Soldier, is_friendship: bool) -> int:
	var count = 0
	var threshold = FRIEND_THRESHOLD if is_friendship else RIVAL_THRESHOLD
	
	for other_id in soldier.relationships:
		var value = soldier.relationships[other_id]
		if (is_friendship and value >= threshold) or (not is_friendship and value <= -threshold):
			count += 1
	
	return count

func _on_event_completed(event, involved_soldiers, choice_index):
	if involved_soldiers.size() < 2:
		return
	
	# Record shared event experience
	for i in range(involved_soldiers.size()):
		var soldier1 = involved_soldiers[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, involved_soldiers.size()):
			var soldier2 = involved_soldiers[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			# Track that these soldiers shared an event
			var key = get_relationship_key(soldier1.id, soldier2.id)
			if not key in event_history:
				event_history[key] = 0
			event_history[key] += 1
			
			# Apply shared experience modifier
			modify_relationship(soldier1.id, soldier2.id, SHARED_EVENT_MODIFIER)
	
	# Check for explicit relationship change from event
	if choice_index < event.choices.size():
		var choice = event.choices[choice_index]
		for consequence in choice.consequences:
			if consequence.type == EventConsequence.ConsequenceType.RELATIONSHIP_CHANGE:
				if involved_soldiers.size() >= 2:
					modify_relationship(
						involved_soldiers[0].id,
						involved_soldiers[1].id,
						consequence.value
					)

func _on_trait_expressed(soldier: Soldier, expressed_trait: String):
	if not soldier or not soldier.is_alive:
		return
	
	# Process all other soldiers' reactions to this trait expression
	for other_soldier in soldiers_reference:
		if not other_soldier or not other_soldier.is_alive or other_soldier.id == soldier.id:
			continue
		
		var relationship_change = 0.0
		
		# Check for trait reactions
		for current_trait in other_soldier.traits:
			# Direct trait opposition
			if current_trait.trait_name in opposite_traits and expressed_trait in opposite_traits[current_trait.trait_name]:
				relationship_change -= 10
			
			# Same trait = positive reaction
			if current_trait.trait_name == expressed_trait:
				relationship_change += 8
		
		# Check for attribute tension
		var attribute_category = get_trait_attribute_category(expressed_trait)
		if attribute_category != "":
			for other_trait in other_soldier.traits:
				var other_category = get_trait_attribute_category(other_trait.trait_name)
				
				# Opposing attribute categories create tension
				if (attribute_category == "andreia" and other_category == "logos") or \
				   (attribute_category == "logos" and other_category == "andreia"):
					relationship_change += ATTRIBUTE_TENSION_VALUE
		
		# Apply relationship change if significant
		if relationship_change != 0:
			modify_relationship(soldier.id, other_soldier.id, relationship_change)
		
		# Add notification for significant changes
		if abs(relationship_change) >= 8:
			var formation_grid_node = formation_grid as Node
			if formation_grid_node and formation_grid_node.has_method("add_notification"):
				var message = ""
				if relationship_change > 0:
					message = "%s approves of %s's %s" % [
						other_soldier.soldier_name,
						soldier.soldier_name,
						expressed_trait.to_lower()
					]
				else:
					message = "%s disapproves of %s's %s" % [
						other_soldier.soldier_name,
						soldier.soldier_name,
						expressed_trait.to_lower()
					]
				formation_grid_node.add_notification(message)

func get_trait_attribute_category(trait_name: String) -> String:
	# Map traits to their primary attribute category
	var andreia_traits = ["Brave", "Disciplined", "Methodical", "Aggressive"]
	var logos_traits = ["Inspiring", "Adaptable", "Strategist", "Orator"]
	
	if trait_name in andreia_traits:
		return "andreia"
	elif trait_name in logos_traits:
		return "logos"
	
	return ""

func find_soldier_by_id(id: String) -> Soldier:
	for soldier in soldiers_reference:
		if soldier and soldier.id == id:
			return soldier
	return null

func get_relationship_key(id1: String, id2: String) -> String:
	# Ensure consistent ordering for relationship keys
	if id1 < id2:
		return id1 + "_" + id2
	else:
		return id2 + "_" + id1

func get_relationships_for_soldier(soldier: Soldier) -> Dictionary:
	var relationships = {}
	for other_id in soldier.relationships:
		var other_soldier = find_soldier_by_id(other_id)
		if other_soldier and other_soldier.is_alive:
			relationships[other_id] = {
				"soldier": other_soldier,
				"value": soldier.relationships[other_id]
			}
	return relationships

func get_relationship_type(value: int) -> String:
	if value >= 80:
		return "Close Friend"
	elif value >= FRIEND_THRESHOLD:
		return "Friend"
	elif value > -20:
		return "Neutral"
	elif value > RIVAL_THRESHOLD:
		return "Disliked"
	else:
		return "Rival"

func get_relationship_color(value: int) -> Color:
	if value >= 80:
		return Color(0, 0.8, 0)  # Bright Green
	elif value >= FRIEND_THRESHOLD:
		return Color(0, 0.6, 0)  # Green
	elif value > -20:
		return Color(0.7, 0.7, 0.7)  # Gray
	elif value > RIVAL_THRESHOLD:
		return Color(0.8, 0.3, 0)  # Orange
	else:
		return Color(0.9, 0, 0)  # Red

func get_cohesion_bonus_for_formation() -> float:
	var total_bonus = 0.0
	
	# Check all pairs for positive relationships
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			if soldier2.id in soldier1.relationships:
				var value = soldier1.relationships[soldier2.id]
				
				# Positive relationships add to cohesion
				if value > 0:
					total_bonus += value * 0.1 # +1 cohesion per 10 relationship points
				
				# Negative relationships reduce cohesion
				elif value < 0:
					total_bonus += value * 0.1 # -1 cohesion per 10 relationship points
	
	return total_bonus

func form_significant_relationship(soldier1: Soldier, soldier2: Soldier, is_friendship: bool):
	# This is called from event choices to actually form the relationship
	if not soldier1 or not soldier2:
		return false
	
	# Check limits again (in case things changed since the event was triggered)
	var s1_count = count_relationships(soldier1, is_friendship)
	var s2_count = count_relationships(soldier2, is_friendship)
	
	var max_count = MAX_FRIENDS if is_friendship else MAX_RIVALS
	
	if s1_count >= max_count or s2_count >= max_count:
		print("Relationship limit reached, cannot form new " + 
			  ("friendship" if is_friendship else "rivalry"))
		return false
	
	# Emit signal to notify the system
	significant_relationship_formed.emit(soldier1, soldier2, is_friendship)
	
	# Apply a relationship bonus to cement the bond
	var bonus = 10 if is_friendship else -10
	modify_relationship(soldier1.id, soldier2.id, bonus)
	
	return true
