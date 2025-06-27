extends Resource
class_name GameEvent

# Event identification
@export var event_id: String = ""
@export var event_name: String = ""
@export var event_type: String = "generic"  # battle, peaceful, chain

# Trigger conditions
@export var trigger_tags: Array = []  # ["battle", "morale<5", "trait:brave"]
@export var trigger_chance: float = 1.0  # 0.0 to 1.0
@export var can_repeat: bool = false
@export var cooldown_turns: int = 0

# Event content
@export var event_text: String = ""
@export var choices: Array = []

# Requirements
@export var requires_soldiers: int = 1  # How many soldiers involved
@export var soldier_filters: Array = []  # ["trait:brave", "row:1"]

# Chain events
@export var next_event_id: String = ""  # For event chains
@export var is_chain_event: bool = false

# State tracking
var times_triggered: int = 0
var last_triggered_turn: int = -1

func can_trigger(current_turn: int, available_soldiers: Array) -> bool:
	# Check cooldown
	if last_triggered_turn >= 0 and current_turn - last_triggered_turn < cooldown_turns:
		return false
	
	# Check if can repeat
	if not can_repeat and times_triggered > 0:
		return false
	
	# Check soldier requirements
	var valid_soldiers = filter_soldiers(available_soldiers)
	if valid_soldiers.size() < requires_soldiers:
		return false
	
	# Check random chance
	return randf() <= trigger_chance

func filter_soldiers(soldiers: Array) -> Array:
	var filtered = []
	
	for soldier in soldiers:
		var passes_all_filters = true
		for filter in soldier_filters:
			if not check_soldier_filter(soldier, filter):
				passes_all_filters = false
				break
		if passes_all_filters:
			filtered.append(soldier)
	
	return filtered

func check_soldier_filter(soldier: Soldier, filter: String) -> bool:
	var parts = filter.split(":")
	if parts.size() != 2:
		return true
		
	var filter_type = parts[0]
	var filter_value = parts[1]
	
	match filter_type:
		"trait":
			for current_trait in soldier.traits:
				if current_trait.trait_name == filter_value:
					return true
			return false
		"row":
			# This will need formation position info
			return true  # Placeholder
		"stat":
			# Parse stat requirements like "morale>10"
			return true  # Placeholder
		_:
			return true

func trigger_event():
	times_triggered += 1
	# Don't reference EventManager here - let the manager handle turn tracking
