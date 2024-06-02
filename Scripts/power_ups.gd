extends Area2D

@onready var anim = $AnimationPlayer

@export var type = 0


func _ready():
	if type == 0:
		anim.play("Speed")
	elif type == 1:
		anim.play("Bomb")
	elif type == 2:
		anim.play("Flame")
	elif type == 3:
		anim.play("Skull")


func _on_area_entered(area):
	queue_free()
