extends Area2D

@onready var anim = $AnimationPlayer

@export var type = 0


func _ready():
	if type >= 0 and type <= 0.19:
		type = 0
		anim.play("Speed")
	elif type >= 0.20 and type <= 0.54:
		type = 1
		anim.play("Bomb")
	elif type >= 0.55 and type <= 0.89:
		type = 2
		anim.play("Flame")
	else:
		type = 3
		anim.play("Skull")


func _on_area_entered(_area):
	queue_free()
