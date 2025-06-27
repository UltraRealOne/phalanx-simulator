extends Node
class_name EulogyGenerator

var eulogy_templates: Dictionary = {}

func _ready():
	load_eulogy_templates()

func load_eulogy_templates():
	var file = FileAccess.open("res://data/eulogies/eulogy_templates.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			eulogy_templates = json.data
			print("Loaded eulogy templates: ", eulogy_templates.keys())
		else:
			print("Error parsing eulogy templates")
	else:
		print("Could not open eulogy templates file")

func generate_eulogy(fallen: Soldier, eulogist: Soldier) -> Dictionary:
	var eulogy = {
		"speaker": eulogist,
		"text": "",
		"emotion": ""
	}
	
	# Determine relationship category
	var relationship = 0
	if fallen.id in eulogist.relationships:
		relationship = eulogist.relationships[fallen.id]
	
	var category = get_relationship_category(relationship)
	eulogy["emotion"] = category
	
	# Get appropriate template
	var templates = eulogy_templates.get(category, [])
	if templates.size() > 0:
		var template = templates[randi() % templates.size()]
		eulogy["text"] = format_eulogy_text(template, fallen, eulogist)
	else:
		eulogy["text"] = generate_generic_eulogy(fallen, eulogist)
	
	return eulogy

func get_relationship_category(relationship: int) -> String:
	if relationship >= 80:
		return "close_friend"
	elif relationship >= 50:
		return "friend"
	elif relationship >= 0:
		return "neutral"
	elif relationship >= -50:
		return "disliked"
	else:
		return "rival"

func format_eulogy_text(template: String, fallen: Soldier, eulogist: Soldier) -> String:
	var text = template
	
	# Replace placeholders
	text = text.replace("[FALLEN_NAME]", fallen.soldier_name)
	text = text.replace("[SPEAKER_NAME]", eulogist.soldier_name)
	text = text.replace("[FALLEN_NATIONALITY]", fallen.nationality)
	
	# Replace trait references
	if fallen.traits.size() > 0:
		var trait_name = fallen.traits[0].trait_name
		text = text.replace("[FALLEN_TRAIT]", trait_name.to_lower())
	else:
		text = text.replace("[FALLEN_TRAIT]", "steadfast")
	
	# Replace battle references
	text = text.replace("[BATTLES_SURVIVED]", str(fallen.battles_survived))
	
	return text

func generate_generic_eulogy(fallen: Soldier, eulogist: Soldier) -> String:
	return "%s was a soldier of %s. They fought bravely and will be remembered." % [
		fallen.soldier_name,
		fallen.nationality
	]
