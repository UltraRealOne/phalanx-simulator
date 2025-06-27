extends Resource
class_name Soldier

# Core Attributes (1-20)
@export var health: int = 10
@export var morale: int = 10
@export var andreia: int = 10  # Bravery/Combat skill, physical discipline
@export var logos: int = 10  # Leadership/Rhetoric, social discipline, adaptation

# Identity
@export var soldier_name: String = ""
@export var nationality: String = "Macedonian"
@export var age: int = 20

# Traits (max 4)
@export var traits: Array = []

# Relationships (Dictionary: soldier_id -> relationship_value)
var relationships: Dictionary = {}

# Combat stats
@export var battles_survived: int = 0
@export var kills: int = 0
@export var is_wounded: bool = false
@export var is_alive: bool = true

# Visual
@export var sprite_index: int = 0
@export var color_index: int = 0

# Unique identifier
var id: String = ""

func _init():
	id = generate_unique_id()
	# Clamp initial values
	health = clamp(health, 1, 20)
	morale = clamp(morale, 1, 20)
	andreia = clamp(andreia, 1, 20)
	logos = clamp(logos, 1, 20)

func generate_unique_id() -> String:
	return str(Time.get_unix_time_from_system()) + "_" + str(randi())

func get_total_stats() -> int:
	return health + morale + andreia + logos

func add_trait(new_trait) -> bool:
	# Check if soldier already has this trait
	for existing_trait in traits:
		if existing_trait.trait_name == new_trait.trait_name:
			return false  # Don't add duplicate
	
	# Check if there's room for more traits
	if traits.size() < 4:
		traits.append(new_trait)
		new_trait.apply_to_soldier(self)
		return true
	return false

func remove_trait(trait_to_remove):
	traits.erase(trait_to_remove)

func modify_attribute(attribute: String, value: int):
	match attribute:
		"health":
			health = clamp(health + value, 1, 20)
		"morale":
			morale = clamp(morale + value, 1, 20)
		"andreia":
			andreia = clamp(andreia + value, 1, 20)
		"logos":
			logos = clamp(logos + value, 1, 20)

func get_attribute_color(attribute: String) -> Color:
	match attribute:
		"health":
			return Color.RED
		"morale":
			return Color.YELLOW
		"andreia":
			return Color.ORANGE
		"logos":
			return Color.PURPLE
		_:
			return Color.WHITE
