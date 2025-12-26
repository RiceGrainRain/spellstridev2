extends Node2D
class_name Unit

signal move_finished(unit: Unit)
signal downed_finished(unit: Unit)

signal hp_changed(unit: Unit, new_hp: int, old_hp: int)
signal ap_changed(unit: Unit, new_ap: int, old_ap: int)
signal armor_changed(unit: Unit, new_armor: int, old_armor: int)

@export var team_id: int = 0

# Data-driven loadout
@export var class_stats: ClassStats
@export var anim_profile: AnimationProfile
@export var vfx_profile: AttackVFXProfile
@export var fx_anchor_path: NodePath = NodePath("")

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Runtime state
var ap: int = 0
var hp: int = 0
var armor: int = 0

var cell: Vector2i
var is_moving: bool = false
var is_downed: bool = false


func _ready() -> void:
	if anim_profile != null and anim_profile.idle != "":
		$AnimatedSprite2D.play(anim_profile.idle)

	# Initialize from ClassStats (authoritative defaults)
	if class_stats != null:
		hp = class_stats.max_hp
		ap = class_stats.max_ap
		armor = class_stats.armor
	else:
		# Safe fallbacks
		hp = 1
		ap = 0
		armor = 0

	# Optional: emit initial values so UI can bind late and still render correctly
	hp_changed.emit(self, hp, hp)
	ap_changed.emit(self, ap, ap)
	armor_changed.emit(self, armor, armor)


# -------------------------
# Grid placement
# -------------------------
func set_cell(new_cell: Vector2i, grid: GridManager) -> void:
	cell = new_cell
	global_position = grid.cell_to_world_center(cell)


# -------------------------
# Action economy
# -------------------------
func reset_ap() -> void:
	set_ap(class_stats.max_ap if class_stats != null else 0)

func spend_ap(cost: int) -> bool:
	if cost <= 0:
		return true
	if ap < cost:
		return false
	set_ap(ap - cost)
	return true

func set_ap(new_ap: int) -> void:
	var old := ap
	ap = max(new_ap, 0)
	if ap != old:
		ap_changed.emit(self, ap, old)

func set_armor(new_armor: int) -> void:
	var old := armor
	armor = max(new_armor, 0)
	if armor != old:
		armor_changed.emit(self, armor, old)


# -------------------------
# Life state
# -------------------------
func is_alive() -> bool:
	return hp > 0 and not is_downed

func take_damage(amount: int) -> void:
	var remaining: int = max(amount, 0)

	if remaining <= 0:
		return

	if armor > 0:
		var absorbed: int = min(armor, remaining)
		set_armor(armor - absorbed)
		remaining -= absorbed

	if remaining > 0:
		var old_hp := hp
		hp = max(hp - remaining, 0)
		if hp != old_hp:
			hp_changed.emit(self, hp, old_hp)


# -------------------------
# Downed / death visuals
# -------------------------
func down_and_play_animation() -> void:
	if is_downed:
		return

	is_downed = true
	set_ap(0)
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
	tween.tween_property(self, "global_position", target_pos, class_stats.move_duration if class_stats != null else 0.2)

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
