# ActionResolver.gd
extends Node
class_name ActionResolver

signal action_started(action_type: String)
signal action_finished(action_type: String)

@export var post_attack_delay_sec: float = 0.08

var turn_manager: TurnManager
var grid: GridManager
var units_root: Node = null

# Match-owned state
var occupied: Dictionary = {} # Vector2i -> Unit
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(
	tm: TurnManager,
	grid_manager: GridManager,
	units_node: Node,
	occupied_dict: Dictionary,
	rng_ref: RandomNumberGenerator
) -> void:
	turn_manager = tm
	grid = grid_manager
	units_root = units_node
	occupied = occupied_dict
	rng = rng_ref

func can_act_with(unit: Unit) -> bool:
	if unit == null:
		return false
	if turn_manager == null or grid == null:
		return false
	if not turn_manager.can_accept_input():
		return false
	if not turn_manager.unit_is_on_active_team(unit):
		return false
	if not unit.is_alive():
		return false
	if unit.is_moving:
		return false
	return true

# -------------------------
# MOVE
# -------------------------
func do_move(unit: Unit, target_cell: Vector2i) -> bool:
	if not can_act_with(unit):
		print("do_move: cannot act with unit")
		return false

	if not grid.is_walkable(target_cell):
		print("do_move: not walkable")
		return false
	if occupied.has(target_cell):
		print("do_move: occupied")
		return false

	var reachable: Array[Vector2i] = grid.get_reachable_cells(unit.cell, unit.ap)
	if not reachable.has(target_cell):
		print("do_move: not reachable")
		return false

	var cost: int = grid.manhattan_distance(unit.cell, target_cell)
	if cost <= 0 or cost > unit.ap:
		print("do_move: bad cost", cost, " ap=", unit.ap)
		return false

	turn_manager.on_action_started()
	action_started.emit("move")

	occupied.erase(unit.cell)
	unit.ap -= cost
	occupied[target_cell] = unit

	# Start move (no callback) and await the signal from Unit
	unit.move_to_cell(target_cell, grid, Callable())
	await unit.move_finished

	action_finished.emit("move")
	turn_manager.on_action_finished()
	return true

# -------------------------
# ATTACK
# -------------------------
func do_attack(attacker: Unit, defender: Unit) -> bool:
	if attacker == null or defender == null:
		print("do_attack: null unit")
		return false
	if turn_manager == null or grid == null:
		print("do_attack: missing refs")
		return false
	if not turn_manager.can_accept_input():
		print("do_attack: input not accepted. phase=", turn_manager.phase, " locked=", turn_manager.is_input_locked())
		return false
	if not turn_manager.unit_is_on_active_team(attacker):
		print("do_attack: attacker not on active team")
		return false
	if not attacker.is_alive() or not defender.is_alive():
		print("do_attack: someone dead")
		return false
	if attacker.team_id == defender.team_id:
		print("do_attack: same team")
		return false
	if attacker.ap < attacker.attack_ap_cost:
		print("do_attack: not enough AP")
		return false

	var dist: int = grid.manhattan_distance(attacker.cell, defender.cell)
	if dist > attacker.attack_range:
		print("do_attack: out of range dist=", dist, " range=", attacker.attack_range)
		return false

	turn_manager.on_action_started()
	action_started.emit("attack")

	attacker.ap -= attacker.attack_ap_cost

	var roll: int = rng.randi_range(1, 20)
	var attack_score: int = roll + attacker.accuracy
	var defense_score: int = 10 + defender.evasion
	var margin: int = attack_score - defense_score

	var tier_name: String = ""
	var dmg_mult: float = 1.0

	if margin <= -5:
		tier_name = "GLANCE"
		dmg_mult = 0.5
	elif margin <= 4:
		tier_name = "NORMAL"
		dmg_mult = 1.0
	elif margin <= 9:
		tier_name = "STRONG"
		dmg_mult = 1.15
	else:
		tier_name = "CRITICAL"
		dmg_mult = 1.25

	var dmg: int = int(round(attacker.base_damage * dmg_mult))
	defender.take_damage(dmg)

	print(attacker.name, "rolled", roll, "(", attack_score, "vs", defense_score, "margin", margin, ") =>", tier_name, "for", dmg, "damage.",
		" Defender HP:", defender.hp, "/", defender.max_hp, " Attacker AP:", attacker.ap)

	if not defender.is_alive():
		print(defender.name, "DOWNED")
		occupied.erase(defender.cell)
		defender.queue_free()

	if post_attack_delay_sec > 0.0:
		await get_tree().create_timer(post_attack_delay_sec).timeout

	action_finished.emit("attack")
	turn_manager.on_action_finished()
	return true
