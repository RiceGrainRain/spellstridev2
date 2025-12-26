extends Node
class_name GridManager

@export var ground_layer_path: NodePath
@export var blockers_layer_path: NodePath

var ground_layer: TileMapLayer
var blockers_layer: TileMapLayer

# Playable area in GLOBAL CELL coordinates (from GroundLayer)
var grid_rect: Rect2i

# walkable[local_x][local_y] -> bool
var walkable: Array = []

func _ready() -> void:
	ground_layer = get_node_or_null(ground_layer_path) as TileMapLayer
	blockers_layer = get_node_or_null(blockers_layer_path) as TileMapLayer

	if ground_layer == null:
		push_error("GridManager: ground_layer_path invalid or not a TileMapLayer.")
		return
	if blockers_layer == null:
		push_error("GridManager: blockers_layer_path invalid or not a TileMapLayer.")
		return

	_build_from_layers()

func _build_from_layers() -> void:
	grid_rect = ground_layer.get_used_rect()
	if grid_rect.size.x <= 0 or grid_rect.size.y <= 0:
		push_error("GridManager: GroundLayer has no tiles. Paint ground first.")
		return

	# Init walkable grid
	walkable.clear()
	for x in grid_rect.size.x:
		var col: Array = []
		col.resize(grid_rect.size.y)
		for y in grid_rect.size.y:
			col[y] = true
		walkable.append(col)

	# Mark blocked cells where blockers layer has tiles
	var blocked_cells: Array[Vector2i] = blockers_layer.get_used_cells()
	var blocked_in_bounds := 0
	for cell in blocked_cells:
		if grid_rect.has_point(cell):
			var local := cell - grid_rect.position
			walkable[local.x][local.y] = false
			blocked_in_bounds += 1

	print("GridManager: playable rect:", grid_rect, " blocked(in bounds):", blocked_in_bounds)

func rebuild() -> void:
	_build_from_layers()

func is_in_bounds(cell: Vector2i) -> bool:
	return grid_rect.has_point(cell)

func is_walkable(cell: Vector2i) -> bool:
	if not is_in_bounds(cell):
		return false
	var local := cell - grid_rect.position
	return walkable[local.x][local.y]

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(world_pos))

func cell_to_world_center(cell: Vector2i) -> Vector2:
	var center_local: Vector2 = ground_layer.map_to_local(cell)
	return ground_layer.to_global(center_local)

	
func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_reachable_cells(start: Vector2i, max_ap: int) -> Array[Vector2i]:
	# BFS using 4-dir movement; each step costs 1 AP
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = []
	var cost_so_far := {}

	frontier.append(start)
	cost_so_far[start] = 0

	while frontier.size() > 0:
		var current: Vector2i = frontier.pop_front()
		var current_cost: int = cost_so_far[current]

		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var nxt: Vector2i = current + dir
			if not is_walkable(nxt):
				continue

			var new_cost := current_cost + 1
			if new_cost > max_ap:
				continue

			if not cost_so_far.has(nxt) or new_cost < cost_so_far[nxt]:
				cost_so_far[nxt] = new_cost
				frontier.append(nxt)
				result.append(nxt)

	return result
