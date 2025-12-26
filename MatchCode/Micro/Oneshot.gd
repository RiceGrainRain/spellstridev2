extends Node2D
class_name OneShotFx

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if sprite == null:
		queue_free()
		return

	sprite.play()

	sprite.animation_finished.connect(func():
		queue_free()
	)
