extends Node2D

signal selected_unit_changed(unit: Unit)

@onready var grid: GridManager = $Controllers/GridManager
@onready var overlay: GridOverlay = $Level/GridOverlay
@onready var units_node: Node2D = $Units

@onready var turn_manager: TurnManager = $Controllers/TurnManager
@onready var action_resolver: ActionResolver = $Controllers/ActionResolver

# UI (this node MUST have SelectedUnitPanel.gd attached)
@onready var unit_hud: SelectedUnitPanel = $MatchHUD/UnitHUD

var selected_unit: Unit = null
var occupied: Dictionary = {} # Vector2i -> Unit

var input_locked: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	overlay.set_grid(grid)
	occupied.clear()

	# Debug the actual HUD reference + script attachment
	print("=== HUD DEBUG ===")
	print("Running scene:", get_tree().current_scene.name)

	print("Has MatchHUD:", has_node("MatchHUD"))
	print("Has MatchHUD/UnitHUD:", has_node("MatchHUD/UnitHUD"))

	var hud := get_node_or_null("MatchHUD/UnitHUD")
	print("hud node:", hud)

	if hud != null:
		print("hud class:", hud.get_class())
		print("hud script:", hud.get_script())
		if hud is CanvasItem:
			print("hud visible:", (hud as CanvasItem).visible)
			print("hud modulate:", (hud as CanvasItem).modulate)

		if hud is Control:
			var c := hud as Control
			print("hud size:", c.size, " pos:", c.global_position, " anchors:", c.anchor_left, c.anchor_top, c.anchor_right, c.anchor_bottom)

			# FORCE it on-screen for testing (won't hurt anything)
			c.visible = true
			c.modulate = Color(1, 1, 1, 1)
			c.top_level = true
			c.global_position = Vector2(40, 40)
			c.size = Vector2(300, 120)
	print("=================")

	# Connect selection -> HUD (ONE pathway)
	selected_unit_changed.connect(func(u: Unit) -> void:
		unit_hud.bind(u) # or unit_hud.show_unit(u) depending on your script
	)

	# Init units
	for child in units_node.get_children():
		if child is Unit:
			var u := child as Unit
			var c := grid.world_to_cell(u.global_position)
			u.set_cell(c, grid)
			u.reset_ap()
			occupied[c] = u
			print("INIT unit:", u.name, " team=", u.team_id, " cell=", u.cell, " hp=", u.hp, " ap=", u.ap)

	turn_manager.input_locked_changed.connect(func(locked: bool) -> void:
		input_locked = locked
	)

	turn_manager.team_turn_started.connect(func(team_id: int) -> void:
		print("TURN START: team", team_id)
		if selected_unit != null and selected_unit.team_id != team_id:
			clear_selection()
	)

	turn_manager.team_turn_ended.connect(func(team_id: int) -> void:
		print("TURN END: team", team_id)
	)

	turn_manager.match_won.connect(func(winning_team_id: int) -> void:
		print("MATCH OVER: team", winning_team_id, "wins!")
		clear_selection()
		overlay.clear()
	)

	action_resolver.setup(turn_manager, grid, units_node, occupied, rng)
	turn_manager.start_match(units_node)

	for child in units_node.get_children():
		if child is Unit:
			selected_unit_changed.emit(child as Unit)
			break

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_just_pressed("end_turn"):
			turn_manager.end_turn()
			return

	if not turn_manager.can_accept_input():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_world: Vector2 = get_global_mouse_position()
		var clicked_cell: Vector2i = grid.world_to_cell(mouse_world)

		var clicked_unit := _get_unit_hit(mouse_world)
		if clicked_unit != null:
			if selected_unit != null and clicked_unit != selected_unit and clicked_unit.team_id != selected_unit.team_id:
				await try_attack_selected(clicked_unit)
				return

			if clicked_unit.team_id != turn_manager.active_team_id:
				clear_selection()
				return

			select_unit(clicked_unit)
			return

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

	# Notify UI (the ONLY call you need)
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
