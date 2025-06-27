extends Node
class_name FuneralManager

signal funeral_started
signal soldier_mourned(soldier: Soldier)
signal funeral_completed
signal funeral_event_triggered(event: GameEvent)

# Funeral state
var fallen_soldiers: Array[Soldier] = []
var surviving_soldiers: Array[Soldier] = []
var current_fallen_index: int = 0
var memorial_records: Array[MemorialRecord] = []

# Configuration
@export var min_eulogies_per_soldier: int = 1
@export var max_eulogies_per_soldier: int = 3
@export var morale_penalty_friend_death: int = -3
@export var morale_penalty_commander_death: int = -5
@export var morale_boost_eulogy: int = 1

# References
var eulogy_generator: EulogyGenerator

func _ready():
	eulogy_generator = EulogyGenerator.new()
	add_child(eulogy_generator)

func setup_funeral(fallen: Array[Soldier], survivors: Array[Soldier]):
	fallen_soldiers = fallen
	surviving_soldiers = survivors
	current_fallen_index = 0  # Reset index
	memorial_records.clear()
	
	# Sort fallen by importance (commander first, then by total stats)
	fallen_soldiers.sort_custom(sort_by_importance)
	
	# Calculate relationships for eulogy selection
	calculate_survivor_reactions()
	
	print("Funeral setup with %d fallen, %d survivors" % [fallen.size(), survivors.size()])

func sort_by_importance(a: Soldier, b: Soldier) -> bool:
	# Commander or Acting Commander check
	var a_is_commander = a.soldier_name.begins_with("Commander ") or a.soldier_name.begins_with("Acting Commander ")
	var b_is_commander = b.soldier_name.begins_with("Commander ") or b.soldier_name.begins_with("Acting Commander ")
	
	if a_is_commander and not b_is_commander:
		return true
	if b_is_commander and not a_is_commander:
		return false
	
	return a.get_total_stats() > b.get_total_stats()

func calculate_survivor_reactions():
	for fallen in fallen_soldiers:
		var record = MemorialRecord.new()
		record.soldier = fallen
		
		print("\nCalculating reactions for fallen: ", fallen.soldier_name)
		
		# Find soldiers who knew the fallen
		var close_friends = []
		var friends = []
		var acquaintances = []
		var rivals = []
		
		for survivor in surviving_soldiers:
			if fallen.id in survivor.relationships:
				var relationship = survivor.relationships[fallen.id]
				print("  %s has relationship %d with fallen" % [survivor.soldier_name, relationship])
				
				if relationship >= 80:
					close_friends.append(survivor)
				elif relationship >= 50:
					friends.append(survivor)
				elif relationship >= -50:
					acquaintances.append(survivor)
				else:
					rivals.append(survivor)
		
		print("  Close friends: ", close_friends.size())
		print("  Friends: ", friends.size())
		print("  Acquaintances: ", acquaintances.size())
		print("  Rivals: ", rivals.size())
		
		# Select eulogists based on relationships
		record.eulogists = select_eulogists(close_friends, friends, acquaintances, rivals)
		print("  Selected eulogists: ", record.eulogists.size())
		memorial_records.append(record)

func select_eulogists(close_friends: Array, friends: Array, acquaintances: Array, rivals: Array) -> Array[Soldier]:
	var eulogists: Array[Soldier] = []  # Make this a typed array
	
	# Priority: close friends > friends > acquaintances > rivals
	if close_friends.size() > 0:
		var to_add = close_friends.slice(0, min(2, close_friends.size()))
		for soldier in to_add:
			eulogists.append(soldier as Soldier)
	
	if eulogists.size() < max_eulogies_per_soldier and friends.size() > 0:
		var needed = max_eulogies_per_soldier - eulogists.size()
		var to_add = friends.slice(0, min(needed, friends.size()))
		for soldier in to_add:
			eulogists.append(soldier as Soldier)
	
	if eulogists.size() < min_eulogies_per_soldier and acquaintances.size() > 0:
		var needed = min_eulogies_per_soldier - eulogists.size()
		var to_add = acquaintances.slice(0, min(needed, acquaintances.size()))
		for soldier in to_add:
			eulogists.append(soldier as Soldier)
	
	# Add one rival for drama if space available
	if eulogists.size() < max_eulogies_per_soldier and rivals.size() > 0:
		eulogists.append(rivals[0] as Soldier)
	
	return eulogists

func start_funeral():
	current_fallen_index = 0  # Make sure index starts at 0
	funeral_started.emit()
	process_next_fallen()

func process_next_fallen():
	print("Processing fallen %d of %d" % [current_fallen_index + 1, fallen_soldiers.size()])
	
	if current_fallen_index >= fallen_soldiers.size():
		complete_funeral()
		return
	
	var fallen = fallen_soldiers[current_fallen_index]
	var record = memorial_records[current_fallen_index]
	
	print("Fallen soldier: ", fallen.soldier_name)
	print("Eulogists: ", record.eulogists.size())
	
	# Generate eulogies - fix the type
	var eulogies: Array[Dictionary] = []  # Typed array
	for eulogist in record.eulogists:
		var eulogy = eulogy_generator.generate_eulogy(fallen, eulogist)
		eulogies.append(eulogy)
		print("Eulogy from %s: %s" % [eulogist.soldier_name, eulogy["text"]])
	
	record.eulogies = eulogies
	
	# Apply morale effects
	apply_death_morale_effects(fallen, record.eulogists)
	
	soldier_mourned.emit(fallen)

func apply_death_morale_effects(fallen: Soldier, eulogists: Array[Soldier]):
	# Commander death affects everyone
	var is_commander = fallen.soldier_name.begins_with("Commander ") or fallen.soldier_name.begins_with("Acting Commander ")
	if is_commander:
		for survivor in surviving_soldiers:
			survivor.modify_attribute("morale", morale_penalty_commander_death)
			print("%s lost %d morale (commander death)" % [survivor.soldier_name, morale_penalty_commander_death])
	
	# Friend death affects specific soldiers
	for survivor in surviving_soldiers:
		if fallen.id in survivor.relationships:
			var relationship = survivor.relationships[fallen.id]
			if relationship >= 50: # Friend
				survivor.modify_attribute("morale", morale_penalty_friend_death)
				print("%s lost %d morale (friend death)" % [survivor.soldier_name, morale_penalty_friend_death])
	
	# Eulogists get small morale boost for honoring the dead
	for eulogist in eulogists:
		eulogist.modify_attribute("morale", morale_boost_eulogy)
		print("%s gained %d morale (gave eulogy)" % [eulogist.soldier_name, morale_boost_eulogy])

func advance_to_next_fallen():
	current_fallen_index += 1
	process_next_fallen()

func complete_funeral():
	funeral_completed.emit()
	print("Funeral ceremony completed")

func get_current_memorial() -> MemorialRecord:
	if current_fallen_index < memorial_records.size():
		return memorial_records[current_fallen_index]
	return null
