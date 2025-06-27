extends Resource
class_name Trait

enum TraitType {
	POSITIVE,
	NEGATIVE,
	CROSS_TRAIT
}

enum TraitCategory {
	CONSTITUTION,
	RESOLVE,
	ANDREIA,
	LOGOS
}

@export var trait_name: String = ""
@export var description: String = ""
@export var type: TraitType = TraitType.POSITIVE
@export var category: TraitCategory = TraitCategory.CONSTITUTION
@export var icon_path: String = ""

# Attribute modifiers
@export var health_modifier: int = 0
@export var morale_modifier: int = 0
@export var andreia_modifier: int = 0
@export var logos_modifier: int = 0

# Special effects (for future implementation)
@export var special_effects: Dictionary = {}

func apply_to_soldier(soldier: Soldier):
	soldier.health += health_modifier
	soldier.morale += morale_modifier
	soldier.andreia += andreia_modifier
	soldier.logos += logos_modifier
	
	# Clamp values
	soldier.health = clamp(soldier.health, 1, 20)
	soldier.morale = clamp(soldier.morale, 1, 20)
	soldier.andreia = clamp(soldier.andreia, 1, 20)
	soldier.logos = clamp(soldier.logos, 1, 20)
