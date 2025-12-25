extends Resource
class_name AnimationProfile

@export var idle: String = "idle"

@export var walk_left: String = "walk_left"
@export var walk_right: String = "walk_right"
@export var walk_up: String = "walk_up"
@export var walk_down: String = "walk_down"

@export var attack_left: String = "attack_left"
@export var attack_right: String = "attack_right"
@export var attack_up: String = "attack_up"
@export var attack_down: String = "attack_down"
@export var downed: String = "downed"

func walk_for_dir(dir: Vector2i) -> String:
	if abs(dir.x) > abs(dir.y):
		return walk_right if dir.x > 0 else walk_left
	else:
		return walk_down if dir.y > 0 else walk_up

func attack_for_dir(dir: Vector2i) -> String:
	if abs(dir.x) > abs(dir.y):
		return attack_right if dir.x > 0 else attack_left
	else:
		return attack_down if dir.y > 0 else attack_up
