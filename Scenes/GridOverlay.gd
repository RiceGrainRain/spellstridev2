extends Node2D
class_name GridOverlay

var grid: GridManager
var tiles: Array[Vector2i] = []

func set_grid(g: GridManager) -> void:
	grid = g

func set_tiles(new_tiles: Array[Vector2i]) -> void:
	tiles = new_tiles
	queue_redraw()

func clear() -> void:
	tiles.clear()
	queue_redraw()

func _draw() -> void:
	if grid == null or grid.ground_layer == null:
		return

	var tile_size: Vector2 = Vector2(grid.ground_layer.tile_set.tile_size)

	for cell in tiles:
		# Convert world position to this node's LOCAL drawing space
		var center_world: Vector2 = grid.cell_to_world_center(cell)
		var center_local: Vector2 = to_local(center_world)

		var top_left := center_local - tile_size * 0.5
		draw_rect(Rect2(top_left, tile_size), Color(0.0, 0.6, 1.0, 0.35), true)
