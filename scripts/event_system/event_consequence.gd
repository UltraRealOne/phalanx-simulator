extends Resource
class_name EventConsequence

enum ConsequenceType {
	STAT_CHANGE = 0,
	ADD_TRAIT = 1,
	REMOVE_TRAIT = 2,
	RELATIONSHIP_CHANGE = 3,
	DEATH = 4,
	WOUND = 5,
	HEAL = 6,
	FORM_FRIENDSHIP = 7,
	FORM_RIVALRY = 8
}

@export var type: ConsequenceType = ConsequenceType.STAT_CHANGE
@export var target: String = "self"  # self, other, all, random
@export var value: int = 0  # Amount for stat changes
@export var stat_name: String = ""  # For stat changes
@export var trait_name: String = ""  # For trait changes
@export var text_override: String = ""  # Custom consequence text

func apply_to_soldier(soldier: Soldier, other_soldier: Soldier = null):
	match type:
		ConsequenceType.STAT_CHANGE:
			if stat_name != "":
				soldier.modify_attribute(stat_name, value)
		ConsequenceType.ADD_TRAIT:
			# Don't load trait here - let the manager handle it
			pass
		ConsequenceType.RELATIONSHIP_CHANGE:
			if other_soldier:
				# Get the current scene tree via the soldier's node
				var tree = soldier.get_tree()
				if tree:
					var relationship_managers = tree.get_nodes_in_group("relationship_manager")
					if relationship_managers.size() > 0:
						relationship_managers[0].modify_relationship(soldier.id, other_soldier.id, value)
					else:
						print("Warning: No RelationshipManager found to apply relationship change")
				else:
					print("Warning: Cannot access scene tree to find RelationshipManager")
		ConsequenceType.FORM_FRIENDSHIP:
			if other_soldier:
				# Get relationship manager
				var relationship_manager = null
				var nodes = soldier.get_tree().get_nodes_in_group("relationship_manager")
				if nodes.size() > 0:
					relationship_manager = nodes[0]
				if relationship_manager:
					relationship_manager.form_significant_relationship(soldier, other_soldier, true)
		
		ConsequenceType.FORM_RIVALRY:
			if other_soldier:
				# Get relationship manager
				var relationship_manager = null
				var nodes = soldier.get_tree().get_nodes_in_group("relationship_manager")
				if nodes.size() > 0:
					relationship_manager = nodes[0]
				if relationship_manager:
					relationship_manager.form_significant_relationship(soldier, other_soldier, false)
		ConsequenceType.DEATH:
			soldier.is_alive = false
		ConsequenceType.WOUND:
			soldier.is_wounded = true
		ConsequenceType.HEAL:
			soldier.is_wounded = false

func get_description(soldier_name: String) -> String:
	if text_override != "":
		return text_override.replace("[SOLDIER]", soldier_name)
	
	match type:
		ConsequenceType.STAT_CHANGE:
			var change_text = "gains" if value > 0 else "loses"
			return "%s %s %d %s" % [soldier_name, change_text, abs(value), stat_name]
		ConsequenceType.ADD_TRAIT:
			return "%s gains trait: %s" % [soldier_name, trait_name]
		ConsequenceType.REMOVE_TRAIT:
			return "%s loses trait: %s" % [soldier_name, trait_name]
		ConsequenceType.DEATH:
			return "%s dies" % soldier_name
		ConsequenceType.WOUND:
			return "%s is wounded" % soldier_name
		ConsequenceType.HEAL:
			return "%s is healed" % soldier_name
		_:
			return ""
