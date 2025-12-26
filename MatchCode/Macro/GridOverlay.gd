extends Node2D
class_name GridOverlay

var grid: GridManager
var tiles: Array[Vector2i] = []
var show_only_tiles: bool = true

@export var grid_line_color: Color = Color(1, 1, 1, 0.35)
@export var grid_line_width: float = 1.0
@export var highlight_color: Color = Color(0.0, 0.6, 1.0, 0.35)

func set_grid(g: GridManager) -> void:
	grid = g
	queue_redraw()

func set_tiles(new_tiles: Array[Vector2i]) -> void:
	tiles = new_tiles
	queue_redraw()

func clear() -> void:
	tiles.clear()
	queue_redraw()

func _draw() -> void:
	if grid == null or grid.ground_layer == null:
		return
	if tiles.is_empty():
		return  # nothing selected, show nothing

	var ground := grid.ground_layer
	var tile_size: Vector2 = Vector2(ground.tile_set.tile_size)

	_draw_highlights(ground, tile_size)
	_draw_tile_outlines(ground, tile_size)

func _cell_top_left_overlay_local(ground: TileMapLayer, cell: Vector2i, tile_size: Vector2) -> Vector2:
	# map_to_local returns center in Godot 4 for square tiles
	var center_local: Vector2 = ground.map_to_local(cell)
	var top_left_local: Vector2 = center_local - tile_size * 0.5
	var world_pos: Vector2 = ground.to_global(top_left_local)
	return to_local(world_pos)

func _draw_tile_outlines(ground: TileMapLayer, tile_size: Vector2) -> void:
	for cell in tiles:
		var top_left := _cell_top_left_overlay_local(ground, cell, tile_size)
		draw_rect(Rect2(top_left, tile_size), grid_line_color, false, grid_line_width)

func _draw_highlights(ground: TileMapLayer, tile_size: Vector2) -> void:
	for cell in tiles:
		var top_left := _cell_top_left_overlay_local(ground, cell, tile_size)
		draw_rect(Rect2(top_left, tile_size), highlight_color, true)
