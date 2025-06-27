extends Resource
class_name MemorialRecord

@export var soldier: Soldier
@export var eulogists: Array[Soldier] = []
@export var eulogies: Array[Dictionary] = []
@export var death_battle: String = ""
@export var death_date: String = ""
@export var special_circumstances: String = ""

func get_memorial_text() -> String:
	var text = "%s\n" % soldier.soldier_name
	text += "%s of %s\n" % [soldier.age, soldier.nationality]
	text += "Fell in %s\n\n" % death_battle
	
	for eulogy in eulogies:
		var speaker = eulogy["speaker"] as Soldier
		text += "%s says:\n\"%s\"\n\n" % [speaker.soldier_name, eulogy["text"]]
	
	return text

func to_save_data() -> Dictionary:
	return {
		"soldier_name": soldier.soldier_name,
		"soldier_traits": soldier.traits.map(func(t): return t.trait_name),
		"death_battle": death_battle,
		"eulogies": eulogies.map(func(e): return {
			"speaker": e["speaker"].soldier_name,
			"text": e["text"],
			"emotion": e["emotion"]
		})
	}
