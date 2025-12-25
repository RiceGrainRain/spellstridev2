extends Node2D

@onready var grid: GridManager = $Controllers/GridManager
@onready var overlay: GridOverlay = $GridOverlay
@onready var units_node: Node2D = $Units

var selected_unit: Unit = null
var occupied: Dictionary = {} # Vector2i -> Unit
var input_locked: bool = false

func _ready() -> void:
	overlay.set_grid(grid)
	occupied.clear()

	for child in units_node.get_children():
		if child is Unit:
			var u := child as Unit
			var c := grid.world_to_cell(u.global_position)
			u.set_cell(c, grid)
			u.reset_ap()
			occupied[c] = u
			print("INIT unit:", u.name, " cell=", u.cell, " ap=", u.ap)

func _unhandled_input(event: InputEvent) -> void:
	if input_locked:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world: Vector2 = get_global_mouse_position()
		var clicked_cell: Vector2i = grid.world_to_cell(mouse_world)

		# 1) Select unit by forgiving hit test
		var hit_unit := _get_unit_hit(mouse_world)
		if hit_unit != null:
			select_unit(hit_unit)
			return

		# 2) Move selected unit if click is on a reachable tile
		if selected_unit != null:
			try_move_selected(clicked_cell)
			return

		clear_selection()

func _get_unit_hit(world_pos: Vector2) -> Unit:
	# Clicking is "finicky" if we only compare cell coords.
	# This checks if your click is within the unit's tile rect (with padding).
	var tile_size: Vector2 = Vector2(grid.ground_layer.tile_set.tile_size)

	for child in units_node.get_children():
		if child is Unit:
			var u := child as Unit
			var center := grid.cell_to_world_center(u.cell)
			var rect := Rect2(center - tile_size * 0.5, tile_size)
			rect = rect.grow(4.0) # forgiving padding
			if rect.has_point(world_pos):
				return u

	return null

func select_unit(u: Unit) -> void:
	if selected_unit != null:
		_set_unit_selected(selected_unit, false)

	selected_unit = u
	_set_unit_selected(u, true)
	_update_overlay_for_selected()

func clear_selection() -> void:
	if selected_unit != null:
		_set_unit_selected(selected_unit, false)
	selected_unit = null
	overlay.clear()

func _set_unit_selected(u: Unit, is_selected: bool) -> void:
	var ring := u.get_node_or_null("SelectionRing")
	if ring != null and ring is CanvasItem:
		(ring as CanvasItem).visible = is_selected

func _update_overlay_for_selected() -> void:
	if selected_unit == null or selected_unit.ap <= 0:
		overlay.clear()
		return

	var reachable: Array[Vector2i] = grid.get_reachable_cells(selected_unit.cell, selected_unit.ap)
	overlay.set_tiles(reachable)

func try_move_selected(target_cell: Vector2i) -> void:
	if not grid.is_walkable(target_cell):
		return
	if occupied.has(target_cell):
		return

	var reachable: Array[Vector2i] = grid.get_reachable_cells(selected_unit.cell, selected_unit.ap)
	if not reachable.has(target_cell):
		return

	var cost: int = grid.manhattan_distance(selected_unit.cell, target_cell)
	if cost <= 0:
		return
	if cost > selected_unit.ap:
		return

	execute_move(selected_unit, target_cell, cost)

func execute_move(u: Unit, target_cell: Vector2i, cost: int) -> void:
	input_locked = true

	# Update occupancy immediately (logic)
	occupied.erase(u.cell)
	u.ap -= cost
	occupied[target_cell] = u

	u.move_to_cell(target_cell, grid, func():
		input_locked = false
		_update_overlay_for_selected()
	)
