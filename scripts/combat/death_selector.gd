extends RefCounted
class_name DeathSelector

func select_casualties(soldiers: Array, casualty_count: int, battle_manager: BattleManager = null) -> Array:
	var casualties = []
	var alive_soldiers = []
	
	# Get alive soldiers
	for soldier in soldiers:
		if soldier and soldier.is_alive:  # Add null check
			alive_soldiers.append(soldier)
	
	# Calculate death weights
	var weights = []
	for soldier in alive_soldiers:
		weights.append(calculate_death_weight(soldier, soldiers, battle_manager))
	
	# Select casualties based on weights
	for i in range(min(casualty_count, alive_soldiers.size())):
		var selected_index = weighted_random_selection(weights)
		if selected_index >= 0:
			casualties.append(alive_soldiers[selected_index])
			weights[selected_index] = 0  # Prevent re-selection
	
	return casualties

func calculate_death_weight(soldier: Soldier, all_soldiers: Array, battle_manager = null) -> float:
	var weight = 1.0
	
	# Get cohesion modifier if battle manager is available
	if battle_manager:
		# Lower cohesion = higher death chance
		var cohesion_modifier = 100.0 / max(battle_manager.current_cohesion, 30.0)
		weight *= cohesion_modifier
	
	# Position modifier
	var position = find_soldier_position(soldier, all_soldiers)
	if position >= 0:
		var row = position / 8
		var col = position % 8
		
		# Front row more dangerous
		if row == 0:
			weight *= 1.3
		elif row == 2:
			weight *= 0.8
		
		# Flanks more dangerous
		if col == 0 or col == 7:
			weight *= 1.1
	
	# Health modifier
	weight *= (20.0 - soldier.health) / 10.0
	
	# Trait modifiers
	for current_trait in soldier.traits:
		if current_trait.trait_name == "Iron Body":
			weight *= 0.8
		elif current_trait.trait_name == "Coward":
			weight *= 1.3
		elif current_trait.trait_name == "Disciplined":
			weight *= 0.9
	
	# Commander protection (including Acting Commanders)
	if soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander "):
		weight *= 0.6
	
	# Relationship drama
	weight *= calculate_dramatic_weight(soldier, all_soldiers)
	
	return max(0.1, weight)

func find_soldier_position(soldier: Soldier, all_soldiers: Array) -> int:
	for i in range(all_soldiers.size()):
		if all_soldiers[i] and all_soldiers[i].id == soldier.id:  # Add null check
			return i
	return -1

func calculate_dramatic_weight(soldier: Soldier, all_soldiers: Array) -> float:
	var drama_weight = 1.0
	
	# Check for close friends
	for other in all_soldiers:
		if not other:  # Add null check
			continue
			
		if other.id == soldier.id:
			continue
		
		if soldier.id in other.relationships:
			var relationship = other.relationships[soldier.id]
			
			# Dramatic death of friends
			if relationship > 70:
				if randf() < 0.3:  # 30% chance for drama
					drama_weight *= 1.5
			
			# Rivals might die together
			elif relationship < -50:
				if randf() < 0.2:  # 20% chance
					drama_weight *= 1.3
	
	return drama_weight

func weighted_random_selection(weights: Array) -> int:
	var total_weight = 0.0
	for weight in weights:
		total_weight += weight
	
	if total_weight <= 0:
		return -1
	
	var random_value = randf() * total_weight
	var cumulative_weight = 0.0
	
	for i in range(weights.size()):
		cumulative_weight += weights[i]
		if random_value <= cumulative_weight:
			return i
	
	return weights.size() - 1
