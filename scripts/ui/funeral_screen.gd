extends Control

signal begin_ceremony
signal funeral_completed

@onready var background_fade = $BackgroundFade
@onready var fallen_portrait = $VBoxContainer/FallenSection/Portrait
@onready var fallen_name = $VBoxContainer/FallenSection/NameLabel
@onready var fallen_details = $VBoxContainer/FallenSection/DetailsLabel
@onready var eulogies_container = $VBoxContainer/EulogiesSection/ScrollContainer/EulogiesVBox
@onready var continue_button = $VBoxContainer/ContinueButton

var funeral_manager: FuneralManager
var current_eulogy_index: int = 0
var current_memorial: MemorialRecord
var morale_changes_container: VBoxContainer

func setup_funeral(fallen: Array[Soldier], survivors: Array[Soldier]):
	funeral_manager = FuneralManager.new()
	add_child(funeral_manager)
	
	# Connect signals
	funeral_manager.funeral_started.connect(_on_funeral_started)
	funeral_manager.soldier_mourned.connect(_on_soldier_mourned)
	funeral_manager.funeral_completed.connect(_on_funeral_completed)
	
	# Setup funeral
	funeral_manager.setup_funeral(fallen, survivors)
	
	# Configure UI
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.text = "Begin Ceremony"

func _ready():
	print("Funeral screen ready - checking nodes:")
	print("  background_fade: ", background_fade)
	print("  fallen_portrait: ", fallen_portrait)
	print("  fallen_name: ", fallen_name)
	print("  fallen_details: ", fallen_details)
	print("  eulogies_container: ", eulogies_container)
	print("  continue_button: ", continue_button)
	
	# Fade in effect
	if background_fade:
		background_fade.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(background_fade, "modulate:a", 0.7, 1.0)

func _on_funeral_started():
	continue_button.text = "Continue"

func _on_soldier_mourned(soldier: Soldier):
	# Clear any existing content first
	for child in eulogies_container.get_children():
		child.queue_free()
	
	current_eulogy_index = 0  # Reset index
	continue_button.text = "Continue"  # Reset button text
	
	current_memorial = funeral_manager.get_current_memorial()
	display_fallen_soldier(soldier)
	
	# Wait for next frame to ensure children are cleared
	await get_tree().process_frame
	
	display_eulogies()

func display_fallen_soldier(soldier: Soldier):
	# Update fallen soldier display
	fallen_name.text = soldier.soldier_name
	
	var details = "%d years old, %s\n" % [soldier.age, soldier.nationality]
	details += "Battles Survived: %d\n" % soldier.battles_survived
	
	var is_commander = soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander ")
	if is_commander:
		details += "★ COMMANDER ★\n"
	
	# List traits
	if soldier.traits.size() > 0:
		details += "\nTraits:\n"
		for current_trait in soldier.traits:
			details += "• %s\n" % current_trait.trait_name
	
	fallen_details.text = details
	
	# Create placeholder portrait
	update_portrait(soldier)

func update_portrait(soldier: Soldier):
	# Clear existing portrait
	for child in fallen_portrait.get_children():
		child.queue_free()
	
	# This would display soldier sprite/portrait
	# For now, just a colored rectangle
	var rect = ColorRect.new()
	rect.custom_minimum_size = Vector2(100, 100)
	rect.color = Color(0.3, 0.3, 0.3)
	
	var is_commander = soldier.soldier_name.begins_with("Commander ") or soldier.soldier_name.begins_with("Acting Commander ")
	if is_commander:
		rect.color = Color(0.5, 0.3, 0.3)
	
	fallen_portrait.add_child(rect)

func display_eulogies():
	# Double-check container is clear
	for child in eulogies_container.get_children():
		child.queue_free()
	
	current_eulogy_index = 0
	
	# Wait for cleanup to complete
	await get_tree().process_frame
	
	# Create all eulogy cards but keep them hidden
	for eulogy in current_memorial.eulogies:
		var eulogy_card = create_eulogy_card(eulogy)
		eulogy_card.modulate.a = 0
		eulogies_container.add_child(eulogy_card)
	
	# Reveal first eulogy
	if eulogies_container.get_child_count() > 0:
		reveal_next_eulogy()

func create_eulogy_card(eulogy: Dictionary) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(500, 150)  # Increased height more
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Add a visible background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	
	# Set border widths individually
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.4, 0.4)
	
	# Set content margins individually - more padding
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	
	card.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# Make VBox fill the card
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var speaker_label = Label.new()
	speaker_label.text = eulogy["speaker"].soldier_name + " speaks:"
	speaker_label.add_theme_font_size_override("font_size", 20)
	speaker_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(speaker_label)
	
	# Use RichTextLabel for better text handling
	var text_label = RichTextLabel.new()
	text_label.text = '"' + eulogy["text"] + '"'
	text_label.fit_content = false  # Don't auto-size
	text_label.custom_minimum_size.y = 80  # Fixed height for text area
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.scroll_active = false  # Disable scrolling
	text_label.bbcode_enabled = false
	text_label.add_theme_font_size_override("normal_font_size", 20)
	vbox.add_child(text_label)
	
	# Add emotion indicator
	var emotion_label = Label.new()
	emotion_label.text = "(" + eulogy["emotion"].replace("_", " ").capitalize() + ")"
	emotion_label.add_theme_font_size_override("font_size", 11)
	emotion_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	emotion_label.add_theme_constant_override("line_spacing", -5)  # Reduce spacing
	vbox.add_child(emotion_label)
	
	return card

func reveal_next_eulogy():
	var children = eulogies_container.get_children()
	if current_eulogy_index < children.size():
		var eulogy_card = children[current_eulogy_index]
		var tween = create_tween()
		tween.tween_property(eulogy_card, "modulate:a", 1.0, 0.5)
		current_eulogy_index += 1

func _on_continue_pressed():
	print("Button clicked. Current text: ", continue_button.text)
	
	if continue_button.text == "Begin Ceremony":
		# Emit the signal when ceremony begins
		begin_ceremony.emit()
		funeral_manager.start_funeral()
	
	if continue_button.text == "Begin Ceremony":
		funeral_manager.start_funeral()
	elif continue_button.text == "End Ceremony":
		_on_end_ceremony()
	elif continue_button.text == "Next Soldier":
		# Clear eulogies and morale display
		for child in eulogies_container.get_children():
			child.queue_free()
		current_eulogy_index = 0  # Reset eulogy index
		funeral_manager.advance_to_next_fallen()
		# Don't change button text here - wait for soldier_mourned signal
	elif current_eulogy_index < eulogies_container.get_child_count():
		reveal_next_eulogy()
	else:
		# Check if we're at the last fallen soldier
		if funeral_manager.current_fallen_index >= funeral_manager.fallen_soldiers.size() - 1:
			# This is the last soldier
			if continue_button.text == "Continue":
				display_morale_changes()
				continue_button.text = "End Ceremony"
		else:
			# More soldiers to mourn
			if continue_button.text == "Continue":
				display_morale_changes()
				continue_button.text = "Next Soldier"

func _on_funeral_completed():
	# Just set the text - don't call display_morale_changes again
	print("Funeral completed signal received")
	continue_button.text = "End Ceremony"

func _on_end_ceremony():
	funeral_completed.emit()
	queue_free()

func display_morale_changes():
	# Safety check
	if funeral_manager.current_fallen_index >= funeral_manager.fallen_soldiers.size():
		return
		
	# Count how many morale lines we'll have
	var line_count = 0
	var fallen = funeral_manager.fallen_soldiers[funeral_manager.current_fallen_index]
	var eulogists = current_memorial.eulogists
	var is_commander = fallen.soldier_name.begins_with("Commander ") or fallen.soldier_name.begins_with("Acting Commander ")
	
	if is_commander:
		line_count += 1
	
	# Count friend deaths
	for survivor in funeral_manager.surviving_soldiers:
		if fallen.id in survivor.relationships:
			var relationship = survivor.relationships[fallen.id]
			if relationship >= 50:
				line_count += 1
	
	# Count eulogists
	line_count += eulogists.size()
	
	# Calculate panel height based on line count
	var panel_height = 80 + (line_count * 25)  # Base height + lines
	
	# Create morale summary panel
	var summary_panel = Panel.new()
	summary_panel.custom_minimum_size = Vector2(500, panel_height)
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Make it scrollable if too tall
	if panel_height > 300:
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(500, 300)
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eulogies_container.add_child(scroll)
		scroll.add_child(summary_panel)
	else:
		eulogies_container.add_child(summary_panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.3)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	summary_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	summary_panel.add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Title
	var title = Label.new()
	title.text = "Morale Effects"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(title)
	
	# Commander death effect
	if is_commander:
		add_morale_line(vbox, "All soldiers: -5 morale (commander death)", Color(0.8, 0.2, 0.2))
	
	# Friend deaths
	for survivor in funeral_manager.surviving_soldiers:
		if fallen.id in survivor.relationships:
			var relationship = survivor.relationships[fallen.id]
			if relationship >= 50:
				add_morale_line(vbox, "%s: -3 morale (friend death)" % survivor.soldier_name, Color(0.8, 0.4, 0.4))
	
	# Eulogist bonuses
	for eulogist in eulogists:
		add_morale_line(vbox, "%s: +1 morale (gave eulogy)" % eulogist.soldier_name, Color(0.4, 0.8, 0.4))
	
	# Animate the panel or scroll container
	var animate_target = summary_panel
	if panel_height > 300:
		animate_target = summary_panel.get_parent()  # The scroll container
	
	animate_target.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(animate_target, "modulate:a", 1.0, 0.5)

func add_morale_line(parent: VBoxContainer, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
