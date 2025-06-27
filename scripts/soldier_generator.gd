extends Node
class_name SoldierGenerator

var names_data: Dictionary = {}
var traits_data: Array = []
var nationalities_data: Array = []

func _ready():
	load_data_files()

func load_data_files():
	# Load names
	var names_file = FileAccess.open("res://data/names.json", FileAccess.READ)
	if names_file:
		var json_string = names_file.get_as_text()
		names_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			names_data = json.data
	
	# Load traits
	var traits_file = FileAccess.open("res://data/traits.json", FileAccess.READ)
	if traits_file:
		var json_string = traits_file.get_as_text()
		traits_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			traits_data = json.data
	
	# Load nationalities
	var nationalities_file = FileAccess.open("res://data/nationalities.json", FileAccess.READ)
	if nationalities_file:
		var json_string = nationalities_file.get_as_text()
		nationalities_file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			nationalities_data = json.data

func generate_soldier(nationality: String = "") -> Soldier:
	var soldier = Soldier.new()
	
	# Set nationality
	if nationality == "":
		nationality = nationalities_data[randi() % nationalities_data.size()]
	soldier.nationality = nationality
	
	# Set name based on nationality
	if nationality in names_data:
		var nationality_names = names_data[nationality]
		soldier.soldier_name = nationality_names[randi() % nationality_names.size()]
	else:
		soldier.soldier_name = "Unknown"
	
	# Generate attributes (weighted towards average)
	soldier.health = generate_weighted_stat()
	soldier.morale = generate_weighted_stat()
	soldier.andreia = generate_weighted_stat()
	soldier.logos = generate_weighted_stat()
	
	# Set age
	soldier.age = 18 + randi() % 22  # 18-39 years old
	
	# Add 1-2 random traits
	var num_traits = 1 + randi() % 2
	var attempts = 0
	var traits_added = 0
	
	while traits_added < num_traits and attempts < 10:
		var new_trait = generate_random_trait()
		if soldier.add_trait(new_trait):
			traits_added += 1
		attempts += 1
	
	# Final clamp to ensure 1-20 range
	soldier.health = clamp(soldier.health, 1, 20)
	soldier.morale = clamp(soldier.morale, 1, 20)
	soldier.andreia = clamp(soldier.andreia, 1, 20)
	soldier.logos = clamp(soldier.logos, 1, 20)
	
	# Set visual properties
	soldier.sprite_index = randi() % 8  # Assuming 8 different sprites
	soldier.color_index = randi() % 4  # Assuming 4 color variations
	
	return soldier

func generate_weighted_stat() -> int:
	# Weighted towards middle values (8-12)
	var roll1 = randi() % 6 + 1
	var roll2 = randi() % 6 + 1
	var roll3 = randi() % 6 + 1
	return 5 + roll1 + roll2 + roll3

func generate_random_trait() -> Trait:
	var trait_data = traits_data[randi() % traits_data.size()]
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
		# Convert any sophrosyne modifiers to logos/andreia as appropriate
		if "sophrosyne" in modifiers:
			# Split sophrosyne bonus between andreia and logos
			var sophrosyne_value = modifiers.get("sophrosyne", 0)
			if sophrosyne_value > 0:
				# For positive traits, split based on trait purpose
				if new_trait.trait_name in ["Disciplined", "Methodical"]:
					new_trait.andreia_modifier += sophrosyne_value
				else:
					new_trait.logos_modifier += sophrosyne_value
			else:
				# For negative traits, split based on trait name
				if new_trait.trait_name in ["Sloppy", "Unruly"]:
					new_trait.andreia_modifier += sophrosyne_value
				else:
					new_trait.logos_modifier += sophrosyne_value
		
		new_trait.logos_modifier = modifiers.get("logos", 0)
	
	return new_trait

func generate_elite_soldier(nationality: String = "") -> Soldier:
	var soldier = generate_soldier(nationality)
	
	# Boost stats
	soldier.health = clamp(soldier.health + 3, 1, 20)
	soldier.morale = clamp(soldier.morale + 3, 1, 20)
	soldier.andreia = clamp(soldier.andreia + 3, 1, 20)
	soldier.logos = clamp(soldier.logos + 3, 1, 20)
	
	# Ensure at least 2 traits
	var attempts = 0
	while soldier.traits.size() < 2 and attempts < 10:
		var new_trait = generate_random_trait()
		soldier.add_trait(new_trait)
		attempts += 1
	
	return soldier
