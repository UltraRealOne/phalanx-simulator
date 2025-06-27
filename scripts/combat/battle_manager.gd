extends Node
class_name BattleManager

signal battle_started
signal casualties_occurred(dead_soldiers: Array)
signal battle_ended
signal replacement_needed(replacement_data: Array)  # Changed from slots_to_fill
signal expected_casualties_updated
signal funeral_needed(dead_soldiers: Array)
signal cohesion_changed(new_cohesion)

# Battle configuration
@export var battle_name: String = ""
@export var historical_casualties: float = 0.1  # 10% default
@export var battle_duration: float = 180.0  # 3 minutes

# Battle state
var current_time: float = 0.0
var is_battle_active: bool = false
var is_paused: bool = false  # Add pause state
var formation_reference: Node2D = null
var soldiers_reference: Array = []
var dead_soldiers: Array = []
var death_times: Dictionary = {}  # soldier_id -> death_time
var pending_replacements: Array = []  # Track replacements needed

# Statistics
var starting_cohesion: float = 100.0
var current_cohesion: float = 100.0
var actual_casualties: int = 0
var expected_casualties: int = 0
var additional_deaths_added: int = 0  # Track how many extra deaths we've added
var dynamic_expected_casualties: int = 0  # Track dynamic expected casualties

var shared_battle_experience: Dictionary = {}  # Format: "soldier1_id_soldier2_id" -> battles_together

func setup_battle(battle_data: Dictionary, formation: Node2D, soldiers: Array):
	battle_name = battle_data.get("name", "Unknown Battle")
	historical_casualties = battle_data.get("casualties", 0.1)
	battle_duration = battle_data.get("duration", 180.0)
	
	formation_reference = formation
	soldiers_reference = soldiers
	dead_soldiers.clear()
	death_times.clear()
	
	# Calculate initial cohesion and save it
	starting_cohesion = calculate_initial_cohesion()
	current_cohesion = starting_cohesion
	calculate_expected_casualties()
	dynamic_expected_casualties = expected_casualties  # Initialize

func calculate_initial_cohesion() -> float:
	# Use same base value as formation_grid
	var cohesion = 50.0
	
	# Commander bonus
	var commander = get_commander()
	if commander:
		var commander_bonus = commander.logos * 0.5
		
		# Reduce effectiveness for acting commander
		if commander.soldier_name.begins_with("Acting Commander ") or commander.has_meta("temp_commander"):
			commander_bonus *= 0.5  # Half effectiveness
			
		cohesion += commander_bonus
	
	# Add formation bonus
	var formation_bonus = calculate_formation_bonus() * 0.5
	cohesion += formation_bonus
	
	# Add relationship bonus using the same method
	var relationship_bonus = 0.0
	# Access relationship manager through formation reference
	if formation_reference and formation_reference.relationship_manager:
		relationship_bonus = formation_reference.relationship_manager.get_cohesion_bonus_for_formation()
	cohesion += relationship_bonus
	
	# Debug print - properly formatted for GDScript
	var commander_bonus = 0.0
	if commander:
		commander_bonus = commander.logos * 0.5
	
	print("Battle manager calculated initial cohesion: ", cohesion)
	print("Components - Base: 50.0, Commander: ", commander_bonus, 
		  ", Formation: ", formation_bonus, ", Relationships: ", relationship_bonus)
	
	return cohesion

func calculate_cohesion():
	var cohesion = 50.0  # Reduced from 100.0 for testing
	var old_cohesion = current_cohesion
	
	# Base cohesion from commander
	var commander = get_commander()
	if commander:
		# Check if temporary commander (50% effectiveness)
		if commander.get_meta("temp_commander", false):
			cohesion += commander.logos * 0.25 # Half effectiveness
		else:
			cohesion += commander.logos * 0.5
			
	if current_cohesion != old_cohesion:
		cohesion_changed.emit(current_cohesion)
	
	# Formation bonuses
	cohesion += calculate_formation_bonus() * 0.5  # Reduced impact
	
	# Relationship bonuses
	cohesion += calculate_relationship_bonus() * 0.05  # Reduced impact
	
	# Trait synergies
	cohesion += calculate_trait_synergies() * 0.5  # Reduced impact
	
	starting_cohesion = cohesion
	current_cohesion = cohesion

func calculate_formation_bonus() -> float:
	var bonus = 0.0
	
	# Check adjacent soldiers for synergies
	for i in range(24):
		var soldier = soldiers_reference[i]
		if not soldier or not soldier.is_alive: # Check for null soldiers
			continue
		
		var row = i / 8
		var col = i % 8
		
		# Check neighbors
		var neighbors = get_neighbors(row, col)
		for neighbor_idx in neighbors:
			if neighbor_idx < soldiers_reference.size():
				var neighbor = soldiers_reference[neighbor_idx]
				if neighbor and neighbor.is_alive:  # Check for null neighbors
					# Basic adjacency bonus
					bonus += 1.0
					
					# Nationality bonus/penalty
					if soldier.nationality == neighbor.nationality:
						bonus += 0.5
					else:
						bonus -= 0.25
	
	return bonus

func calculate_relationship_bonus() -> float:
	var bonus = 0.0
	
	for soldier in soldiers_reference:
		if not soldier or not soldier.is_alive:  # Check for null
			continue
		
		for other_id in soldier.relationships:
			var relationship_value = soldier.relationships[other_id]
			if relationship_value > 50:
				bonus += relationship_value * 0.01
			elif relationship_value < -50:
				bonus -= abs(relationship_value) * 0.01
	
	return bonus

func calculate_trait_synergies() -> float:
	var bonus = 0.0
	
	# Count trait occurrences
	var trait_counts = {}
	for soldier in soldiers_reference:
		if not soldier or not soldier.is_alive:  # Check for null
			continue
		
		for current_trait in soldier.traits:
			if current_trait.trait_name in trait_counts:
				trait_counts[current_trait.trait_name] += 1
			else:
				trait_counts[current_trait.trait_name] = 1
	
	# Apply synergy bonuses
	for trait_name in trait_counts:
		var count = trait_counts[trait_name]
		if count >= 3:
			bonus += count * 0.5
	
	return bonus

func get_neighbors(row: int, col: int) -> Array:
	var neighbors = []
	
	# Check all 8 directions
	for dr in range(-1, 2):
		for dc in range(-1, 2):
			if dr == 0 and dc == 0:
				continue
			
			var new_row = row + dr
			var new_col = col + dc
			
			if new_row >= 0 and new_row < 3 and new_col >= 0 and new_col < 8:
				neighbors.append(new_row * 8 + new_col)
	
	return neighbors

func calculate_expected_casualties():
	var alive_count = 0
	for soldier in soldiers_reference:
		if soldier and soldier.is_alive:  # Check for null
			alive_count += 1
	
	# Apply cohesion modifier
	var cohesion_modifier = 150.0 / max(current_cohesion, 50.0)
	
	# Calculate with randomness
	var randomness = randf_range(0.8, 1.2)
	
	# Apply historical rate
	var base_casualties = alive_count * historical_casualties * cohesion_modifier * randomness
	
	# Ensure minimum casualties for testing
	expected_casualties = max(int(base_casualties), int(alive_count * 0.15))  # At least 15% casualties
	expected_casualties = max(3, expected_casualties)  # At least 3 casualties for testing

func start_battle():
	is_battle_active = true
	current_time = 0.0
	actual_casualties = 0
	
	# Pre-calculate death times
	assign_death_times()
	
	battle_started.emit()
	
	# Track which soldiers fought together
	record_shared_battle_experience()
	
	# Initialize cohesion
	starting_cohesion = calculate_initial_cohesion()
	current_cohesion = starting_cohesion
	
	# Emit signal immediately to update any displays
	cohesion_changed.emit(current_cohesion)

func assign_death_times():
	var death_selector = DeathSelector.new()
	var soldiers_to_die = death_selector.select_casualties(soldiers_reference, expected_casualties, self)  # Pass self
	
	for i in range(soldiers_to_die.size()):
		var soldier = soldiers_to_die[i]
		var death_time = randf() * battle_duration
		death_times[soldier.id] = death_time
		
		# Store position for event notification
		var position = find_soldier_position(soldier)
		if position >= 0:
			soldier.set_meta("last_position", position)

func get_battle_statistics() -> Dictionary:
	return {
		"battle_name": battle_name,
		"expected_casualties": expected_casualties,
		"actual_casualties": actual_casualties,
		"starting_cohesion": starting_cohesion,
		"final_cohesion": current_cohesion,
		"survival_rate": 1.0 - (float(actual_casualties) / soldiers_reference.size())
	}

func find_soldier_position(soldier: Soldier) -> int:
	for i in range(soldiers_reference.size()):
		if soldiers_reference[i] and soldiers_reference[i].id == soldier.id:
			return i
	return -1

func request_replacement(position: int):
	var row = position / 8
	var col = position % 8
	var available_replacements = []
	
	# Calculate which positions can replace based on column
	var behind_row = row + 1
	if behind_row >= 3: # No row behind the third row
		is_paused = false
		return
	
	# Start position in the row behind
	var behind_start = behind_row * 8
	
	# Get soldier directly behind
	var directly_behind = behind_start + col
	if directly_behind < soldiers_reference.size():
		var soldier = soldiers_reference[directly_behind]
		if soldier and soldier.is_alive:  # Check for null
			available_replacements.append(directly_behind)
	
	# Get soldier to the left (if not on left edge)
	if col > 0:
		var left_behind = behind_start + (col - 1)
		if left_behind < soldiers_reference.size():
			var soldier = soldiers_reference[left_behind]
			if soldier and soldier.is_alive:  # Check for null first
				available_replacements.append(left_behind)
	
	# Get soldier to the right (if not on right edge)
	if col < 7:
		var right_behind = behind_start + (col + 1)
		if right_behind < soldiers_reference.size():
			var soldier = soldiers_reference[right_behind]
			if soldier and soldier.is_alive:  # Check for null first
				available_replacements.append(right_behind)
	
	if available_replacements.size() > 0:
		# Emit signal for UI to handle replacement
		replacement_needed.emit([position, available_replacements])
	else:
		# No replacements available, continue battle
		is_paused = false

func update_battle(delta: float):
	if not is_battle_active or is_paused:
		return
	
	current_time += delta
	
	# Check for deaths at current time
	for soldier_id in death_times:
		var death_time = death_times[soldier_id]
		if death_time <= current_time and death_time > current_time - delta:
			execute_death(soldier_id)
	
	# Add additional deaths based on cohesion drop (linear scaling)
	var cohesion_ratio = current_cohesion / starting_cohesion
	if cohesion_ratio < 0.9:  # Start adding deaths when cohesion drops below 90%
		add_dynamic_casualties(cohesion_ratio)
	
	# Check for panic deaths if cohesion is very low (below 50%)
	if cohesion_ratio < 0.5:
		check_panic_deaths(delta)
	
	# Check battle end
	if current_time >= battle_duration:
		end_battle()

func add_dynamic_casualties(cohesion_ratio: float):
	# Calculate how many additional deaths we should have based on cohesion
	var cohesion_penalty = 1.0 - cohesion_ratio
	var additional_deaths_target = int(expected_casualties * cohesion_penalty)
	
	# Update dynamic expected casualties
	dynamic_expected_casualties = expected_casualties + additional_deaths_target
	
	# Only add new deaths if we haven't already
	if additional_deaths_target > additional_deaths_added:
		var deaths_to_add = additional_deaths_target - additional_deaths_added
		
		# Get living soldiers
		var living_soldiers = []
		for i in range(soldiers_reference.size()):
			var soldier = soldiers_reference[i]
			if soldier and soldier.is_alive and not soldier.id in death_times:
				living_soldiers.append(soldier)
		
		# Add new death times for additional casualties
		var death_selector = DeathSelector.new()
		for i in range(min(deaths_to_add, living_soldiers.size())):
			# Use death selector to pick soldiers with proper weighting
			var candidates = death_selector.select_casualties(soldiers_reference, 1, self)
			if candidates.size() > 0:
				var victim = candidates[0]
				# Schedule death in the remaining battle time
				var time_remaining = battle_duration - current_time
				var death_time = current_time + randf() * time_remaining
				death_times[victim.id] = death_time
				
				# Store position for event notification
				var position = find_soldier_position(victim)
				if position >= 0:
					victim.set_meta("last_position", position)
				
				additional_deaths_added += 1

func check_panic_deaths(delta: float):
	# Only occurs below 50% cohesion
	var cohesion_ratio = current_cohesion / starting_cohesion
	
	# Panic chance increases as cohesion drops below 50%
	var panic_multiplier = (0.5 - cohesion_ratio) * 2.0  # 0 at 50%, 1.0 at 0%
	var panic_chance = panic_multiplier * 0.02 * delta  # 2% per second at 0 cohesion
	
	if randf() < panic_chance:
		# Select a random living soldier for panic death
		var living_soldiers = []
		for i in range(soldiers_reference.size()):
			var soldier = soldiers_reference[i]
			if soldier and soldier.is_alive:
				living_soldiers.append({"soldier": soldier, "index": i})
		
		if living_soldiers.size() > 0:
			var victim_data = living_soldiers[randi() % living_soldiers.size()]
			
			# Mark for immediate death
			death_times[victim_data.soldier.id] = current_time + 0.1
			victim_data.soldier.set_meta("last_position", victim_data.index)

func execute_death(soldier_id: String):
	var soldier = find_soldier_by_id(soldier_id)
	if soldier and soldier.is_alive:
		
		# Check if this is the commander (including Acting Commander)
		if soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander "):
			execute_commander_death(soldier)
			return
		
		soldier.is_alive = false
		dead_soldiers.append(soldier)
		actual_casualties += 1
		
		# Find soldier's position
		var position = find_soldier_position(soldier)
		
		# Store position in soldier metadata for visual update
		soldier.set_meta("last_position", position)
		
		# Trigger death event
		casualties_occurred.emit([soldier])
		
		# Update cohesion
		var old_cohesion = current_cohesion
		current_cohesion *= 0.95  # 5% cohesion loss per death
		
		if current_cohesion != old_cohesion:
			cohesion_changed.emit(current_cohesion)
		
		# Recalculate expected casualties based on new cohesion
		update_expected_casualties()
		
		# Check if replacement is needed based on row
		if position >= 0 and position < 16: # First two rows need replacement
			is_paused = true
			pending_replacements.append(position)
			# Add a small delay to show death animation first
			await get_tree().create_timer(0.5).timeout
			request_replacement(position)

func execute_commander_death(commander: Soldier):
	# Pause battle for the special event
	is_paused = true
	
	# Find commander's position and neighbors
	var commander_pos = find_soldier_position(commander)
	var row = commander_pos / 8
	var col = commander_pos % 8
	
	# Get valid neighbors who could sacrifice themselves
	var potential_saviors = []
	var neighbors = get_neighbors(row, col)
	
	for neighbor_idx in neighbors:
		if neighbor_idx < soldiers_reference.size():
			var neighbor = soldiers_reference[neighbor_idx]
			if neighbor and neighbor.is_alive:
				potential_saviors.append(neighbor_idx)
	
	# Trigger commander death event
	if potential_saviors.size() > 0:
		# For now, let's just handle the immediate choice
		# This will be replaced with proper event UI
		commander_death_choice(commander_pos, potential_saviors)
	else:
		# No one can save the commander
		apply_commander_death(commander)
		
	# Update cohesion for losing a soldier (not commander)
		var old_cohesion = current_cohesion
		current_cohesion *= 0.95  # 5% cohesion loss per death
		
	# Recalculate expected casualties
		update_expected_casualties()

func update_expected_casualties():
	# Recalculate based on current cohesion
	var cohesion_ratio = current_cohesion / starting_cohesion
	var cohesion_drop = 1.0 - cohesion_ratio
	
	# More dramatic scaling: square the cohesion drop for exponential impact
	# At 70% cohesion (30% drop): 0.3² = 0.09 -> 9% more casualties
	# But we want more, so let's multiply by a factor
	var casualty_multiplier = 3.0  # Adjust this to tune the impact
	var additional_casualties = int(expected_casualties * cohesion_drop * casualty_multiplier)
	
	# For commander death specifically, ensure minimum impact
	if cohesion_drop >= 0.3 and additional_casualties < 3:  # Commander death is ~30% drop
		additional_casualties = 3
	
	dynamic_expected_casualties = expected_casualties + additional_casualties

func get_dynamic_expected_casualties() -> int:
	return max(dynamic_expected_casualties, expected_casualties)

func commander_death_choice(commander_pos: int, savior_positions: Array):
	# Add 50/50 chance for sacrifice
	var sacrifice_chance = randf()
	
	if savior_positions.size() > 0 and sacrifice_chance < 0.5:  # 50% chance someone will sacrifice
		var savior_pos = savior_positions[0]
		var savior = soldiers_reference[savior_pos]
		
		# Store position before death
		savior.set_meta("death_position", savior_pos)
		savior.set_meta("last_position", savior_pos)
		
		# Savior dies instead
		savior.is_alive = false
		dead_soldiers.append(savior)
		actual_casualties += 1
		
		# Commander survives but is wounded
		var commander = soldiers_reference[commander_pos]
		commander.morale = max(1, commander.morale - 5)
		
		# Update cohesion for losing a soldier (not commander)
		var old_cohesion = current_cohesion
		current_cohesion *= 0.95  # 5% cohesion loss per death
		
		# Trigger death event for the savior FIRST
		casualties_occurred.emit([savior])
		
		# Then handle replacement after a delay
		call_deferred("handle_savior_replacement", savior_pos)
		
		# Update visual display for wounded commander
		if formation_reference:
			formation_reference.update_slot_display(commander_pos, commander)
	else:
		# No one saves commander (50% chance) or no one available
		apply_commander_death(soldiers_reference[commander_pos])

func handle_savior_replacement(savior_pos: int):
	# Wait for visual update
	await get_tree().create_timer(0.5).timeout
	
	# Check if savior needs replacement
	if savior_pos < 16:  # First two rows need replacement
		request_replacement(savior_pos)
	else:
		# No replacement needed, resume battle
		is_paused = false

func apply_commander_death(commander: Soldier):
	# Commander dies - massive morale hit
	commander.is_alive = false
	dead_soldiers.append(commander)
	actual_casualties += 1
	
	# Find commander's position BEFORE promoting new one
	var commander_pos = find_soldier_position(commander)
	
	# Store position for visual update AND for later use
	commander.set_meta("last_position", commander_pos)
	commander.set_meta("death_position", commander_pos)  # Store for replacement
	
	# INCREASE the cohesion drop to have a more significant impact
	var old_cohesion = current_cohesion
	current_cohesion *= 0.6  # 40% reduction instead of 30%
	
	# Recalculate expected casualties based on new cohesion
	var old_expected = expected_casualties
	update_expected_casualties()
	
	# Ensure at least 2-3 more casualties after commander death
	var min_increase = 2
	if expected_casualties < old_expected + min_increase:
		expected_casualties = old_expected + min_increase
	
	# Emit signals
	expected_casualties_updated.emit()
	cohesion_changed.emit(current_cohesion)
	
	print("Commander died - cohesion reduced to:", current_cohesion)
	print("Expected casualties increased from", old_expected, "to", expected_casualties)
	
	# All soldiers lose morale
	for soldier in soldiers_reference:
		if soldier and soldier.is_alive:
			soldier.morale = max(1, soldier.morale - 5)
	
	# Trigger death notification - this shows the visual
	casualties_occurred.emit([commander])
	
	# Wait for death animation to complete
	await get_tree().create_timer(0.5).timeout
	
	# Find temporary commander (highest stats)
	var best_soldier = null
	var best_stats = 0
	var best_position = -1
	
	for i in range(soldiers_reference.size()):
		var soldier = soldiers_reference[i]
		if soldier and soldier.is_alive:
			var total_stats = soldier.get_total_stats()
			if total_stats > best_stats:
				best_stats = total_stats
				best_soldier = soldier
				best_position = i
	
	# Promote temporary commander
	if best_soldier:
		best_soldier.soldier_name = "Acting Commander " + best_soldier.soldier_name
		# Mark as temporary commander with reduced effectiveness
		best_soldier.set_meta("temp_commander", true)
		
		# Update the visual display for the new commander
		if formation_reference:
			formation_reference.update_slot_display(best_position, best_soldier)
	
	# Check if commander needs replacement
	var stored_pos = commander.get_meta("death_position", -1)
	if stored_pos >= 0 and stored_pos < 16:
		request_replacement(stored_pos)
	else:
		# No replacement needed, resume battle
		is_paused = false

func find_soldier_by_id(id: String) -> Soldier:
	for soldier in soldiers_reference:
		if soldier and soldier.id == id:
			return soldier
	return null

func end_battle():
	# Check if we've hit the expected casualty count
	if actual_casualties < expected_casualties:
		print("Battle ending with fewer casualties than expected: %d/%d" % [actual_casualties, expected_casualties])
		
		# Calculate how many casualties are still needed
		var remaining_casualties = expected_casualties - actual_casualties
		
		# Force the remaining casualties
		print("Forcing %d additional casualties before battle end" % remaining_casualties)
		for i in range(remaining_casualties):
			execute_random_death()
	
	# Set battle as inactive
	is_battle_active = false
	
	# Emit signal that battle has ended
	battle_ended.emit()
	
	# Check if funeral is needed
	if dead_soldiers.size() > 0:  # Changed from fallen_soldiers to dead_soldiers
		funeral_needed.emit(dead_soldiers)

func get_commander() -> Soldier:
	for soldier in soldiers_reference:
		if soldier and soldier.is_alive:
			if soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander "):
				return soldier
	return null

func apply_replacement(dead_position: int, replacement_position: int):
	# Move soldier to new position
	var replacement_soldier = soldiers_reference[replacement_position]
	soldiers_reference[dead_position] = replacement_soldier
	soldiers_reference[replacement_position] = null
	
	# Update the formation display
	if formation_reference:
		formation_reference.apply_replacement(dead_position, replacement_position)
	
	# Don't recalculate cohesion - it should only drop, not reset
	# calculate_cohesion() <- Remove this line
	
	# Check if we need to fill the now-empty position
	var replacement_row = replacement_position / 8
	if replacement_row == 1: # If we moved from second row, need to fill from third
		request_replacement(replacement_position)
	else:
		# Resume battle
		is_paused = false
		pending_replacements.clear()

func resume_battle():
	is_paused = false
	is_paused = false

func record_shared_battle_experience():
	# Create a record of soldiers who fought in this battle together
	for i in range(soldiers_reference.size()):
		var soldier1 = soldiers_reference[i]
		if not soldier1 or not soldier1.is_alive:
			continue
		
		for j in range(i + 1, soldiers_reference.size()):
			var soldier2 = soldiers_reference[j]
			if not soldier2 or not soldier2.is_alive:
				continue
			
			# Create a unique key for the pair
			var key = get_relationship_key(soldier1.id, soldier2.id)
			
			# Increment count of battles fought together
			if key in shared_battle_experience:
				shared_battle_experience[key] += 1
			else:
				shared_battle_experience[key] = 1

func get_relationship_key(id1: String, id2: String) -> String:
	# Ensure consistent ordering for relationship keys
	if id1 < id2:
		return id1 + "_" + id2
	else:
		return id2 + "_" + id1

func update_battle_relationships():
	# Find relationship manager
	var relationship_manager = get_node_or_null("/root/Main/FormationGrid/RelationshipManager")
	if not relationship_manager:
		print("Relationship manager not found, can't update battle relationships")
		return
	
	# Apply relationship changes based on shared battle
	for key in shared_battle_experience:
		var ids = key.split("_")
		if ids.size() == 2:
			var soldier1_id = ids[0]
			var soldier2_id = ids[1]
			
			# More battles together = stronger bond
			var battles_together = shared_battle_experience[key]
			var relationship_modifier = sqrt(battles_together) * 2.0
			
			# Apply modifier
			relationship_manager.modify_relationship(soldier1_id, soldier2_id, relationship_modifier)

func execute_random_death():
	# Find all living soldiers
	var living_soldiers = []
	var living_indices = []
	
	for i in range(soldiers_reference.size()):
		var soldier = soldiers_reference[i]
		if soldier and soldier.is_alive:
			living_soldiers.append(soldier)
			living_indices.append(i)
	
	if living_soldiers.size() == 0:
		print("No living soldiers left to kill!")
		return
	
	# Pick a random one to die
	var random_index = randi() % living_soldiers.size()
	var soldier_to_die = living_soldiers[random_index]
	var position = living_indices[random_index]
	
	print("Forcing death of %s at position %d" % [soldier_to_die.soldier_name, position])
	
	# Execute the death
	soldier_to_die.is_alive = false
	soldier_to_die.set_meta("last_position", position)
	actual_casualties += 1
	dead_soldiers.append(soldier_to_die)  # Using dead_soldiers instead of fallen_soldiers
	
	# Emit signal for casualties
	casualties_occurred.emit([soldier_to_die])
	
	# Update cohesion - use a fixed percentage rather than COHESION_LOSS_PER_DEATH
	current_cohesion *= 0.95  # 5% reduction, matching your other death functions
	
	# Check if replacement is needed
	if position >= 0 and position < 16:  # First two rows (16 positions) instead of front_line_positions
		# Mark battle as paused before requesting replacement
		is_paused = true
		# Small delay to let death animation play
		await get_tree().create_timer(0.5).timeout
		# Request replacement
		request_replacement(position)
	else:
		# No replacement needed for back row
		is_paused = false
