extends Node2D
class_name Unit

signal move_finished(unit: Unit)
signal downed_finished(unit: Unit)

@export var team_id: int = 0

# Action economy
@export var max_ap: int = 4
@export var move_duration: float = 0.2

# Combat stats (MVP)
@export var class_id = 1
@export var max_hp: int = 40
@export var accuracy: int = 2
@export var evasion: int = 2
@export var attack_range: int = 1
@export var base_damage: int = 12
@export var attack_ap_cost: int = 2

# Visuals configuration (data-driven per class)
@export var anim_profile: AnimationProfile
@export var vfx_profile: AttackVFXProfile
@export var fx_anchor_path: NodePath = NodePath("") # optional Marker2D/Node2D for FX spawn point

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var ap: int = 4
var hp: int = 40
var cell: Vector2i
var is_moving: bool = false
var is_downed: bool = false

func _ready() -> void:
	hp = max_hp
	ap = max_ap

func set_cell(new_cell: Vector2i, grid: GridManager) -> void:
	cell = new_cell
	global_position = grid.cell_to_world_center(cell)

func reset_ap() -> void:
	ap = max_ap

func is_alive() -> bool:
	# "Alive" for gameplay purposes means not downed and hp > 0
	return hp > 0 and not is_downed

func take_damage(amount: int) -> void:
	hp -= amount
	if hp < 0:
		hp = 0

# -------------------------
# Downed / death visuals
# -------------------------
func down_and_play_animation() -> void:
	if is_downed:
		return

	is_downed = true
	ap = 0
	is_moving = false

	if sprite == null or sprite.sprite_frames == null:
		downed_finished.emit(self)
		return

	var anim_name := "downed"
	if anim_profile != null and anim_profile.downed != "":
		anim_name = anim_profile.downed

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)

		# If downed anim is non-looping, wait for it. If looping, we don't wait.
		if not sprite.sprite_frames.get_animation_loop(anim_name):
			await sprite.animation_finished
	else:
		sprite.stop()

	downed_finished.emit(self)

# -------------------------
# Movement
# -------------------------
func move_to_cell(target_cell: Vector2i, grid: GridManager, on_complete: Callable) -> void:
	if is_moving or is_downed:
		return

	is_moving = true

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

		move_finished.emit(self)

		if on_complete.is_valid():
			on_complete.call()
	)

# -------------------------
# Combat visuals (future-proof hooks)
# -------------------------
func play_impact_fx_from_attacker(attacker: Unit, context: Dictionary = {}) -> void:
	if attacker == null:
		return

	var fx_scene: PackedScene = null

	# Item/weapon override first
	if context.has("impact_fx"):
		fx_scene = context["impact_fx"]
	else:
		# Default: use this unit's VFX profile if present
		if vfx_profile != null:
			fx_scene = vfx_profile.impact_fx

	if fx_scene != null:
		spawn_fx(fx_scene, _fx_anchor_global_pos())

func play_attack_animation_towards_cell(target_cell: Vector2i) -> void:
	if is_downed:
		return
	if sprite == null or sprite.sprite_frames == null:
		return

	var dir := target_cell - cell

	# Pick animation name from anim_profile if available
	var anim_name := ""
	if anim_profile != null:
		anim_name = anim_profile.attack_for_dir(dir)
	else:
		anim_name = _attack_anim_for_direction_fallback(dir)

	if anim_name == "" or not sprite.sprite_frames.has_animation(anim_name):
		_force_idle_reset()
		return

	sprite.play(anim_name)

	# Loop-safe waiting: if it loops, estimate duration instead of waiting forever
	var frames_res := sprite.sprite_frames
	var loops := frames_res.get_animation_loop(anim_name)

	if not loops:
		await sprite.animation_finished
	else:
		var fps := frames_res.get_animation_speed(anim_name)
		var frame_count := frames_res.get_frame_count(anim_name)
		if fps > 0.0 and frame_count > 0:
			await get_tree().create_timer(float(frame_count) / fps).timeout
		else:
			await get_tree().create_timer(0.2).timeout

	_force_idle_reset()

func spawn_fx(scene: PackedScene, at_global_pos: Vector2) -> Node2D:
	if scene == null:
		return null
	var fx := scene.instantiate()
	if fx is Node2D:
		var fx2d := fx as Node2D
		get_tree().current_scene.add_child(fx2d)
		fx2d.global_position = at_global_pos
		return fx2d
	get_tree().current_scene.add_child(fx)
	return null

func _fx_anchor_global_pos() -> Vector2:
	if fx_anchor_path != NodePath(""):
		var n := get_node_or_null(fx_anchor_path)
		if n != null and n is Node2D:
			return (n as Node2D).global_position
	return global_position

# -------------------------
# Anim helpers
# -------------------------
func _play_walk_for_direction(dir: Vector2i) -> void:
	if is_downed:
		return
	if sprite == null or sprite.sprite_frames == null:
		return

	var anim_name := ""
	if anim_profile != null:
		anim_name = anim_profile.walk_for_dir(dir)
	else:
		# fallback to your old naming
		anim_name = _walk_anim_for_direction_fallback(dir)

	_safe_play(anim_name)

func _walk_anim_for_direction_fallback(dir: Vector2i) -> String:
	if abs(dir.x) > abs(dir.y):
		return "walk_right" if dir.x > 0 else "walk_left"
	else:
		return "walk_down" if dir.y > 0 else "walk_up"

func _force_idle_reset() -> void:
	if sprite == null or sprite.sprite_frames == null:
		return

	if is_downed:
		# If downed, stay downed (don't force idle)
		return

	var idle_name := "idle"
	if anim_profile != null and anim_profile.idle != "":
		idle_name = anim_profile.idle

	if sprite.sprite_frames.has_animation(idle_name):
		sprite.play(idle_name)
		sprite.frame = 0
	else:
		sprite.stop()

func _safe_play(anim_name: String) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if anim_name == "":
		_force_idle_reset()
		return

	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	else:
		_force_idle_reset()

func _attack_anim_for_direction_fallback(dir: Vector2i) -> String:
	if abs(dir.x) > abs(dir.y):
		return "attack_right" if dir.x > 0 else "attack_left"
	else:
		return "attack_down" if dir.y > 0 else "attack_up"
