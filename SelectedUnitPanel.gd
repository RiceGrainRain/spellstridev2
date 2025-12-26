extends Control
class_name SelectedUnitPanel

@export var icon_path: NodePath
@export var hp_bar_path: NodePath
@export var ap_bar_path: NodePath

# Optional text labels (assign if you have them)
@export var hp_text_path: NodePath
@export var ap_text_path: NodePath

@onready var icon: TextureRect = get_node_or_null(icon_path) as TextureRect
@onready var hp_bar: TextureProgressBar = get_node_or_null(hp_bar_path) as TextureProgressBar
@onready var ap_bar: TextureProgressBar = get_node_or_null(ap_bar_path) as TextureProgressBar
@onready var hp_text: Label = get_node_or_null(hp_text_path) as Label
@onready var ap_text: Label = get_node_or_null(ap_text_path) as Label

var unit: Unit = null
var hp_max_cached: int = 1
var ap_max_cached: int = 1

func _ready() -> void:
	assert(icon != null, "SelectedUnitPanel: icon_path not set / not TextureRect")
	assert(hp_bar != null, "SelectedUnitPanel: hp_bar_path not set / not TextureProgressBar")
	assert(ap_bar != null, "SelectedUnitPanel: ap_bar_path not set / not TextureProgressBar")
	visible = false

func bind(u: Unit) -> void:
	_show(u)

func show_unit(u: Unit) -> void:
	_show(u)

func _show(u: Unit) -> void:
	_unbind()
	unit = u

	if unit == null:
		visible = false
		return

	visible = true

	icon.texture = unit.class_stats.class_icon

	# Cache maxes (per-unit)
	hp_max_cached = max(1, unit.class_stats.max_hp)
	ap_max_cached = max(1, unit.class_stats.max_ap)

	# Configure bars
	hp_bar.max_value = hp_max_cached
	ap_bar.max_value = ap_max_cached

	# Initial render
	_render_hp(unit.hp)
	_render_ap(unit.ap)

	# Live updates
	unit.hp_changed.connect(_on_hp_changed)
	unit.ap_changed.connect(_on_ap_changed)

func _unbind() -> void:
	if unit == null:
		return
	if unit.hp_changed.is_connected(_on_hp_changed):
		unit.hp_changed.disconnect(_on_hp_changed)
	if unit.ap_changed.is_connected(_on_ap_changed):
		unit.ap_changed.disconnect(_on_ap_changed)
	unit = null

func _on_hp_changed(u: Unit, new_hp: int, _old_hp: int) -> void:
	if u != unit:
		return
	_render_hp(new_hp)

func _on_ap_changed(u: Unit, new_ap: int, _old_ap: int) -> void:
	if u != unit:
		return
	_render_ap(new_ap)

func _render_hp(new_hp: int) -> void:
	var v := clampi(new_hp, 0, hp_max_cached)
	hp_bar.value = v
	if hp_text != null:
		hp_text.text = "%d/%d" % [v, hp_max_cached]

func _render_ap(new_ap: int) -> void:
	var v := clampi(new_ap, 0, ap_max_cached)
	ap_bar.value = v
	if ap_text != null:
		ap_text.text = "%d/%d" % [v, ap_max_cached]
