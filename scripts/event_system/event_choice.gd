extends Resource
class_name EventChoice

@export var choice_text: String = ""
@export var choice_id: String = ""
@export var consequences: Array = []
@export var next_event_id: String = ""  # For branching events
@export var expressed_trait: String = ""

func get_consequences_preview(soldiers: Array) -> String:
	var preview_lines = []
	
	for consequence in consequences:
		# Determine which soldiers would be affected
		var affected_soldiers = []
		
		match consequence.target:
			"self":
				if soldiers.size() > 0:
					affected_soldiers = [soldiers[0]]
			"other":
				if soldiers.size() > 1:
					affected_soldiers = [soldiers[1]]
			"all":
				affected_soldiers = soldiers
			"random":
				if soldiers.size() > 0:
					preview_lines.append("Random soldier:")
					affected_soldiers = [soldiers[0]]  # Show preview for first soldier
		
		# Generate preview for each affected soldier
		for soldier in affected_soldiers:
			var preview = generate_consequence_preview(consequence, soldier)
			if preview != "":
				preview_lines.append(preview)
	
	return "\n".join(preview_lines)

func generate_consequence_preview(consequence: EventConsequence, soldier: Soldier) -> String:
	var preview = soldier.soldier_name + ": "
	
	match consequence.type:
		EventConsequence.ConsequenceType.STAT_CHANGE:
			if consequence.stat_name != "":
				var current_value = soldier.get(consequence.stat_name)
				var new_value = clamp(current_value + consequence.value, 1, 20)
				var arrow = " → " if consequence.value != 0 else " = "
				preview += "%s %d%s%d" % [consequence.stat_name.capitalize(), current_value, arrow, new_value]
		
		EventConsequence.ConsequenceType.ADD_TRAIT:
			preview += "Gains %s" % consequence.trait_name
		
		EventConsequence.ConsequenceType.REMOVE_TRAIT:
			preview += "Loses %s" % consequence.trait_name
		
		EventConsequence.ConsequenceType.DEATH:
			preview += "Dies"
		
		EventConsequence.ConsequenceType.WOUND:
			preview += "Becomes wounded"
		
		EventConsequence.ConsequenceType.HEAL:
			preview += "Heals wounds"
		
		_:
			return ""
	
	return preview
