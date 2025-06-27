extends RefCounted
class_name RelationshipGenerator

# Constants
const INITIAL_RELATIONSHIP_COUNT = 10  # Per soldier
const INITIAL_RELATIONSHIP_VARIANCE = 40  # +/- from neutral
const FRIEND_CHANCE = 0.6  # 60% chance of positive initial relationships
const NATIONALITY_MODIFIER = 20  # Bonus for same nationality

func generate_initial_relationships(soldiers: Array[Soldier], compatibility_matrix: Dictionary):
	# Start with compatibility-based baseline
	for i in range(soldiers.size()):
		var soldier1 = soldiers[i]
		for j in range(i + 1, soldiers.size()):
			var soldier2 = soldiers[j]
			var base_value = calculate_baseline_relationship(soldier1, soldier2, compatibility_matrix)
			
			# Adjust value if it crosses friendship/rivalry threshold
			# 50% chance to reduce below threshold
			if base_value >= 50 and randf() < 0.5:
				base_value = randi_range(30, 45)  # Below friendship threshold
			
			# 50% chance to increase above threshold for negative values
			if base_value <= -50 and randf() < 0.5:
				base_value = randi_range(-45, -30)  # Above rivalry threshold
			
			# Store relationship in both soldiers
			soldier1.relationships[soldier2.id] = base_value
			soldier2.relationships[soldier1.id] = base_value
	
	# Then add random relationships to ensure minimum count
	for soldier in soldiers:
		ensure_minimum_relationships(soldier, soldiers, INITIAL_RELATIONSHIP_COUNT)

func calculate_baseline_relationship(soldier1: Soldier, soldier2: Soldier, compatibility_matrix: Dictionary) -> int:
	var base_value = 0
	
	# Nationality factor - but sometimes people of the same nationality don't get along
	if soldier1.nationality == soldier2.nationality:
		# 70% chance of positive bonus, 30% chance of neutral (no bonus)
		if randf() < 0.7:
			base_value += NATIONALITY_MODIFIER
	else:
		# Check compatibility matrix
		var nationality_key = soldier1.nationality + "_" + soldier2.nationality
		var reverse_key = soldier2.nationality + "_" + soldier1.nationality
		
		if nationality_key in compatibility_matrix.get("nationalities", {}):
			base_value += compatibility_matrix["nationalities"][nationality_key]
		elif reverse_key in compatibility_matrix.get("nationalities", {}):
			base_value += compatibility_matrix["nationalities"][reverse_key]
	
	# Trait compatibility
	for trait1 in soldier1.traits:
		for trait2 in soldier2.traits:
			var trait_key = trait1.trait_name + "_" + trait2.trait_name
			var reverse_key = trait2.trait_name + "_" + trait1.trait_name
			
			if trait_key in compatibility_matrix.get("traits", {}):
				base_value += compatibility_matrix["traits"][trait_key]
			elif reverse_key in compatibility_matrix.get("traits", {}):
				base_value += compatibility_matrix["traits"][reverse_key]
	
	# Add more significant randomness - both positive and negative
	base_value += randi_range(-30, 30)
	
	# Random chance of extreme dislike (people just don't get along sometimes)
	if randf() < 0.1:  # 10% chance
		base_value -= randi_range(40, 70)
	
	return clamp(base_value, -100, 100)

func ensure_minimum_relationships(soldier: Soldier, all_soldiers: Array[Soldier], min_count: int):
	# Count existing relationships
	var relationship_count = soldier.relationships.size()
	
	# Add more random relationships if needed
	while relationship_count < min_count and relationship_count < all_soldiers.size() - 1:
		# Find a soldier with no relationship yet
		var candidate = find_candidate_without_relationship(soldier, all_soldiers)
		if not candidate:
			break
		
		# Generate random relationship
		var value = generate_random_relationship_value()
		
		# Store relationship in both soldiers
		soldier.relationships[candidate.id] = value
		candidate.relationships[soldier.id] = value
		
		relationship_count += 1

func find_candidate_without_relationship(soldier: Soldier, all_soldiers: Array[Soldier]) -> Soldier:
	var candidates = []
	for other in all_soldiers:
		if other.id != soldier.id and not (other.id in soldier.relationships):
			candidates.append(other)
	
	if candidates.size() > 0:
		return candidates[randi() % candidates.size()]
	
	return null

func generate_random_relationship_value() -> int:
	var is_extreme = randf() < 0.4  # 40% chance of extreme values
	
	if is_extreme:
		# Create strong positive or negative relationships
		if randf() < 0.5:
			return randi_range(70, 100)  # Strong positive
		else:
			return randi_range(-100, -70)  # Strong negative
	else:
		var value = randi_range(-60, 60)
		
		if value > 0 and randf() < 0.3:  # 30% chance to flip positive to negative
			value = -value
			
		return value
