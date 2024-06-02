extends Area2D

@onready var anim = $AnimationPlayer
@onready var sprite = $Sprite2D

@export var anim_type = 0
@export var rotate = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if anim_type == 0:
		anim.play("center_explosion")
	elif anim_type == 1:
		anim.play("horizontal_middle_explosion")
	elif anim_type == 2:
		sprite.flip_h = rotate
		anim.play("horizontal_final_explosion")
	elif anim_type == 3:
		anim.play("vertical_middle_explosion")
	elif anim_type == 4:
		sprite.flip_v = rotate
		anim.play("vertical_final_explosion")


func _on_animation_player_animation_finished(anim_name):
	queue_free()
