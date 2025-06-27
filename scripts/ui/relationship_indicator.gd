extends Node2D
class_name RelationshipIndicator

# Line properties
@export var line_width: float = 2.0
@export var positive_color: Color = Color(0, 0.7, 0)
@export var negative_color: Color = Color(0.8, 0, 0)
@export var neutral_color: Color = Color(0.7, 0.7, 0.7)

var soldier1_pos: Vector2
var soldier2_pos: Vector2
var relationship_value: int = 0
var is_selected: bool = false
var soldier1_id: String = ""
var soldier2_id: String = ""

func _ready():
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE
	z_index = 10  # Make sure it's drawn above other elements
	print("Relationship indicator ready - visible: %s, modulate: %s, scale: %s, z_index: %d" % 
		[visible, modulate, scale, z_index])
	update_appearance()

func setup(pos1: Vector2, pos2: Vector2, value: int, id1: String, id2: String):
	print("Setting up relationship indicator: %s <-> %s, value: %d, positions: %s -> %s" % [id1, id2, value, pos1, pos2])
	
	# Convert global positions to local coordinates relative to the relationship_container
	var parent = get_parent()
	if parent:
		soldier1_pos = parent.to_local(pos1)
		soldier2_pos = parent.to_local(pos2)
	else:
		# Fallback in case parent isn't set yet
		soldier1_pos = pos1
		soldier2_pos = pos2
	
	relationship_value = value
	soldier1_id = id1
	soldier2_id = id2
	update_appearance()

func update_appearance():
	queue_redraw()

func _draw():
	if soldier1_pos == Vector2.ZERO or soldier2_pos == Vector2.ZERO:
		print("Error: Invalid positions for relationship line")
		return
	
	var color = get_relationship_color()
	var width = get_relationship_width()
	
	print("Drawing line: value=%d, color=%s" % [relationship_value, color])
	
	# Draw line with the EXACT color returned by get_relationship_color
	draw_line(soldier1_pos, soldier2_pos, color, width)
	
	# Draw circle at midpoint for strong relationships
	if abs(relationship_value) >= 50:
		var midpoint = (soldier1_pos + soldier2_pos) / 2
		var radius = 3.0 + abs(relationship_value) / 20.0
		draw_circle(midpoint, radius, color)

func get_relationship_color() -> Color:
	if is_selected:
		return Color.WHITE
	
	# Use clear, distinct colors based on relationship type
	if relationship_value >= 70:
		return Color(0, 0.9, 0)  # Bright green - strong positive
	elif relationship_value >= 30:
		return Color(0.3, 0.7, 0)  # Medium green - moderate positive
	elif relationship_value > 0:
		return Color(0.5, 0.8, 0.5)  # Light green - weak positive
	elif relationship_value == 0:
		return Color(0.7, 0.7, 0.7)  # Gray - neutral
	elif relationship_value >= -30:
		return Color(0.8, 0.4, 0.4)  # Light red - weak negative
	elif relationship_value >= -70:
		return Color(0.9, 0.2, 0.2)  # Medium red - moderate negative
	else:
		return Color(1.0, 0, 0)  # Bright red - strong negative

func get_relationship_width() -> float:
	var base_width = line_width
	if is_selected:
		base_width *= 2.0
	
	# Scale width by relationship strength
	var strength_scale = 1.0 + abs(relationship_value) / 100.0
	return base_width * strength_scale

func set_selected(selected: bool):
	is_selected = selected
	update_appearance()

func is_point_inside(point: Vector2, tolerance: float = 10.0) -> bool:
	# Check if point is near the line
	var point_on_line = get_closest_point_on_line(point)
	return point.distance_to(point_on_line) <= tolerance

func get_closest_point_on_line(point: Vector2) -> Vector2:
	var line_dir = (soldier2_pos - soldier1_pos).normalized()
	var v = point - soldier1_pos
	var d = v.dot(line_dir)
	var projected = soldier1_pos + line_dir * d
	
	# Check if projected point is within line segment
	var line_length = soldier1_pos.distance_to(soldier2_pos)
	var dist_from_start = soldier1_pos.distance_to(projected)
	
	if dist_from_start > line_length:
		return soldier2_pos
	elif dist_from_start < 0:
		return soldier1_pos
	else:
		return projected
