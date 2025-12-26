extends Control
class_name SelectedUnitPanel

@export var icon_path: NodePath
@export var hp_bar_path: NodePath
@export var ap_bar_path: NodePath

@onready var icon: TextureRect = get_node_or_null(icon_path) as TextureRect
@onready var hp_bar: ProgressBar = get_node_or_null(hp_bar_path) as ProgressBar
@onready var ap_bar: ProgressBar = get_node_or_null(ap_bar_path) as ProgressBar

var unit: Unit = null

func _ready() -> void:
	# Hard fail early with a clear message
	assert(icon != null, "SelectedUnitPanel: icon_path is not set or not a TextureRect")
	assert(hp_bar != null, "SelectedUnitPanel: hp_bar_path is not set or not a ProgressBar")
	assert(ap_bar != null, "SelectedUnitPanel: ap_bar_path is not set or not a ProgressBar")
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
	hp_bar.max_value = unit.class_stats.max_hp
	ap_bar.max_value = unit.class_stats.max_ap
	hp_bar.value = unit.hp
	ap_bar.value = unit.ap

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

func _on_hp_changed(u: Unit, new_hp: int, old_hp: int) -> void:
	if u == unit:
		hp_bar.value = new_hp

func _on_ap_changed(u: Unit, new_ap: int, old_ap: int) -> void:
	if u == unit:
		ap_bar.value = new_ap
