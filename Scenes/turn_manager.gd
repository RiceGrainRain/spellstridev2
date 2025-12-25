extends Node
class_name TurnManager

signal team_turn_started(team_id: int)
signal team_turn_ended(team_id: int)
signal active_team_changed(team_id: int)

signal input_locked_changed(locked: bool)
signal match_won(winning_team_id: int)

enum Phase { TEAM_START, AWAITING_INPUT, RESOLVING_ACTION, TEAM_END, MATCH_OVER }

@export var starting_team_id: int = 0
@export var auto_end_turn_when_no_ap: bool = true

var active_team_id: int = 0
var phase: Phase = Phase.TEAM_START

var _input_locked: bool = false
var _units_root: Node = null

func start_match(units_root: Node) -> void:
	_units_root = units_root
	active_team_id = starting_team_id
	phase = Phase.TEAM_START
	_set_input_locked(false)

	_start_team_turn(active_team_id)

func can_accept_input() -> bool:
	return phase == Phase.AWAITING_INPUT and not _input_locked

func is_match_over() -> bool:
	return phase == Phase.MATCH_OVER

func is_input_locked() -> bool:
	return _input_locked

func lock_input() -> void:
	_set_input_locked(true)

func unlock_input() -> void:
	_set_input_locked(false)

func end_turn() -> void:
	if phase != Phase.AWAITING_INPUT:
		return
	_end_team_turn(active_team_id)

# Call these from ActionResolver to centralize locking + phase
func on_action_started() -> void:
	if phase == Phase.AWAITING_INPUT:
		phase = Phase.RESOLVING_ACTION
	lock_input()

func on_action_finished() -> void:
	if phase == Phase.RESOLVING_ACTION:
		phase = Phase.AWAITING_INPUT
	unlock_input()

	# After any action: win check then optional auto-end
	if _check_win_condition():
		return
	if auto_end_turn_when_no_ap and not team_has_any_ap(active_team_id):
		end_turn()

# -----------------------
# Team + unit helpers
# -----------------------
func get_all_units() -> Array:
	if _units_root == null:
		return []
	return _units_root.get_children()

func get_team_units(team_id: int) -> Array:
	var out: Array = []
	for child in get_all_units():
		if child == null:
			continue
		if not ("team_id" in child):
			continue
		if child.team_id != team_id:
			continue

		if child.has_method("is_alive"):
			if child.is_alive():
				out.append(child)
		else:
			out.append(child)
	return out

func team_has_any_ap(team_id: int) -> bool:
	for u in get_team_units(team_id):
		if "ap" in u and u.ap > 0:
			return true
	return false

func unit_is_on_active_team(u: Node) -> bool:
	return u != null and ("team_id" in u) and u.team_id == active_team_id

func reset_team_resources(team_id: int) -> void:
	# AP reset + reaction hook (future)
	for u in get_team_units(team_id):
		if u.has_method("reset_ap"):
			u.reset_ap()
		elif "max_ap" in u and "ap" in u:
			u.ap = u.max_ap

		# Optional reaction field/hook (won't break if absent)
		if u.has_method("reset_reaction_for_turn"):
			u.reset_reaction_for_turn()
		elif "reaction_available" in u:
			u.reaction_available = true

# -----------------------
# Internal turn flow
# -----------------------
func _start_team_turn(team_id: int) -> void:
	if _check_win_condition():
		return

	phase = Phase.TEAM_START
	reset_team_resources(team_id)

	active_team_changed.emit(team_id)
	team_turn_started.emit(team_id)

	phase = Phase.AWAITING_INPUT
	_set_input_locked(false)

func _end_team_turn(team_id: int) -> void:
	phase = Phase.TEAM_END
	team_turn_ended.emit(team_id)

	active_team_id = 1 - team_id
	_start_team_turn(active_team_id)

func _set_input_locked(locked: bool) -> void:
	if _input_locked == locked:
		return
	_input_locked = locked
	input_locked_changed.emit(_input_locked)

func _check_win_condition() -> bool:
	if _units_root == null:
		return false

	var team0_alive := false
	var team1_alive := false

	for child in get_all_units():
		if child == null:
			continue
		if not ("team_id" in child):
			continue

		var alive := true
		if child.has_method("is_alive"):
			alive = child.is_alive()

		if not alive:
			continue

		if child.team_id == 0:
			team0_alive = true
		elif child.team_id == 1:
			team1_alive = true

	if team0_alive and team1_alive:
		return false

	phase = Phase.MATCH_OVER
	_set_input_locked(true)

	var winner := 0 if team0_alive else 1
	match_won.emit(winner)
	return true
