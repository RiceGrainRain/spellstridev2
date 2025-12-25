extends Node2D
class_name Unit

@export var team_id: int = 0
@export var max_ap: int = 4
@export var move_duration: float = 1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var ap: int = 4
var cell: Vector2i
var is_moving: bool = false

func set_cell(new_cell: Vector2i, grid: GridManager) -> void:
	cell = new_cell
	global_position = grid.cell_to_world_center(cell)

func reset_ap() -> void:
	ap = max_ap

func move_to_cell(target_cell: Vector2i, grid: GridManager, on_complete: Callable) -> void:
	if is_moving:
		return

	is_moving = true

	# Determine direction BEFORE updating cell
	var dir: Vector2i = target_cell - cell

	_play_walk_for_direction(dir)

	# Logic updates immediately
	cell = target_cell

	var target_pos: Vector2 = grid.cell_to_world_center(target_cell)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target_pos, move_duration)

	tween.finished.connect(func():
		is_moving = false
		_force_idle_reset()
		if on_complete.is_valid():
			on_complete.call()
	)

func _play_walk_for_direction(dir: Vector2i) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	var anim_name: String = "idle"

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			anim_name = "walk_right"
		elif dir.x < 0:
			anim_name = "walk_left"
		else:
			anim_name = "idle"
	else:
		if dir.y > 0:
			anim_name = "walk_down"
		elif dir.y < 0:
			anim_name = "walk_up"
		else:
			anim_name = "idle"

	_safe_play(anim_name)

func _force_idle_reset() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
		sprite.frame = 0
	else:
		# If no idle exists, just stop animating
		sprite.stop()

func _safe_play(anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		_force_idle_reset()
