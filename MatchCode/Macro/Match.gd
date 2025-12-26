extends Node2D

signal selected_unit_changed(unit: Unit)

@onready var grid: GridManager = $Controllers/GridManager
@onready var overlay: GridOverlay = $Level/GridOverlay
@onready var units_node: Node2D = $Units

@onready var turn_manager: TurnManager = $Controllers/TurnManager
@onready var action_resolver: ActionResolver = $Controllers/ActionResolver

# UI (UnitHUD is a direct child of Match)
@onready var unit_hud: SelectedUnitPanel = $UnitHUD

var selected_unit: Unit = null
var occupied: Dictionary = {} # Vector2i -> Unit

var input_locked: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	overlay.set_grid(grid)
	occupied.clear()

	# Ensure HUD never blocks world clicks (recursively)
	_set_ui_mouse_filter_recursive(unit_hud, Control.MOUSE_FILTER_IGNORE)

	# Selection -> HUD
	selected_unit_changed.connect(func(u: Unit) -> void:
		if unit_hud != null:
			# Your HUD script can implement either bind() or show_unit().
			if unit_hud.has_method("bind"):
				unit_hud.call("bind", u)
			elif unit_hud.has_method("show_unit"):
				unit_hud.call("show_unit", u)
	)

	# Init units on grid + occupied map
	for child in units_node.get_children():
		if child is Unit:
			var u := child as Unit
			var c := grid.world_to_cell(u.global_position)
			u.set_cell(c, grid)
			u.reset_ap()
			occupied[c] = u

	turn_manager.input_locked_changed.connect(func(locked: bool) -> void:
		input_locked = locked
	)

	turn_manager.team_turn_started.connect(func(team_id: int) -> void:
		if selected_unit != null and selected_unit.team_id != team_id:
			clear_selection()
	)

	turn_manager.match_won.connect(func(winning_team_id: int) -> void:
		clear_selection()
		overlay.clear()
	)

	action_resolver.setup(turn_manager, grid, units_node, occupied, rng)
	turn_manager.start_match(units_node)

	# Start with no selection (HUD hidden/empty depending on your HUD script)
	selected_unit_changed.emit(null)

# Use _input (not _unhandled_input) so world clicks still work even if UI exists.
# Prevent click-through: if mouse is over ANY Control, ignore world input.
func _input(event: InputEvent) -> void:
	# End turn hotkey
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_just_pressed("end_turn"):
			turn_manager.end_turn()
			return

	# If UI is hovered, don't process world clicks
	if event is InputEventMouseButton and event.pressed:
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null:
			return

	if not turn_manager.can_accept_input():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world: Vector2 = get_global_mouse_position()
		var clicked_cell: Vector2i = grid.world_to_cell(mouse_world)

		var clicked_unit := _get_unit_hit(mouse_world)
		if clicked_unit != null:
			# Attack if enemy + you already have a selected unit
			if selected_unit != null and clicked_unit != selected_unit and clicked_unit.team_id != selected_unit.team_id:
				await try_attack_selected(clicked_unit)
				return

			# Can't select enemy units on other team’s turn
			if clicked_unit.team_id != turn_manager.active_team_id:
				clear_selection()
				return

			select_unit(clicked_unit)
			return

		# Clicked empty tile
		if selected_unit != null:
			await try_move_selected(clicked_cell)
			return

		clear_selection()

func _get_unit_hit(world_pos: Vector2) -> Unit:
	var tile_size: Vector2 = Vector2(grid.ground_layer.tile_set.tile_size)
	for child in units_node.get_children():
		if child is Unit:
			var u := child as Unit
			if not u.is_alive():
				continue
			var center := grid.cell_to_world_center(u.cell)
			var rect := Rect2(center - tile_size * 0.5, tile_size).grow(4.0)
			if rect.has_point(world_pos):
				return u
	return null

func select_unit(u: Unit) -> void:
	if u == null or not u.is_alive():
		return
	if u.team_id != turn_manager.active_team_id:
		return

	if selected_unit != null:
		_set_unit_selected(selected_unit, false)

	selected_unit = u
	_set_unit_selected(u, true)
	_update_overlay_for_selected()

	selected_unit_changed.emit(selected_unit)

func clear_selection() -> void:
	if selected_unit != null:
		_set_unit_selected(selected_unit, false)

	selected_unit = null
	overlay.clear()

	selected_unit_changed.emit(null)

func _set_unit_selected(u: Unit, is_selected: bool) -> void:
	var ring := u.get_node_or_null("SelectionRing")
	if ring != null and ring is CanvasItem:
		(ring as CanvasItem).visible = is_selected

func _update_overlay_for_selected() -> void:
	if selected_unit == null or selected_unit.ap <= 0:
		overlay.clear()
		return

	if selected_unit.team_id != turn_manager.active_team_id:
		clear_selection()
		return

	var reachable: Array[Vector2i] = grid.get_reachable_cells(selected_unit.cell, selected_unit.ap)
	reachable.append(selected_unit.cell)
	overlay.set_tiles(reachable)

func try_move_selected(target_cell: Vector2i) -> void:
	if selected_unit == null:
		return
	if selected_unit.team_id != turn_manager.active_team_id:
		return
	if selected_unit.ap <= 0:
		return

	var ok := await action_resolver.do_move(selected_unit, target_cell)
	if ok:
		_update_overlay_for_selected()

func try_attack_selected(target: Unit) -> void:
	if selected_unit == null:
		return
	if not selected_unit.is_alive() or target == null or not target.is_alive():
		return
	if selected_unit.team_id != turn_manager.active_team_id:
		return

	var ok := await action_resolver.do_attack(selected_unit, target)

	if selected_unit != null and not selected_unit.is_alive():
		clear_selection()

	if ok:
		_update_overlay_for_selected()

func _set_ui_mouse_filter_recursive(n: Node, filter: int) -> void:
	if n == null:
		return
	if n is Control:
		(n as Control).mouse_filter = filter
	for c in n.get_children():
		_set_ui_mouse_filter_recursive(c, filter)
