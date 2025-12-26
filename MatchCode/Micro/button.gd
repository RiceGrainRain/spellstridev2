extends Button

# Export variables to easily adjust scale and duration in the Inspector
@export var hover_scale: Vector2 = Vector2(1.2, 1.2) # Scale to increase to (e.g., 1.2x)
@export var animation_duration: float = 0.1 # Duration of the animation in seconds

var original_scale: Vector2
var tween: Tween

func _ready():
	original_scale = scale
	# Ensure pivot is centered for correct scaling (especially in containers)
	call_deferred("init_pivot") # use call_deferred to prevent issues with containers

func init_pivot():
	pivot_offset = size / 2.0

func _on_mouse_entered():
	if tween:
		tween.kill() # Stop any current tween
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) # Smooth transition
	tween.tween_property(self, "scale", hover_scale, animation_duration)

func _on_mouse_exited():
	if tween:
		tween.kill()
	tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", original_scale, animation_duration)
