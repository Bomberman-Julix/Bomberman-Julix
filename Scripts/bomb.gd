extends Node2D


@onready var anim = $AnimationPlayer
@onready var manager = $"../"
@onready var manager_power_up = $"../../PowerUpManager"


@export var set_seed = 0
@export var tile_map = 0
@export var explosion_len = 1


signal exploded
var rng = RandomNumberGenerator.new()


func _ready():
	anim.play("bomb_cd")
	rng.seed = set_seed


func _on_animation_player_animation_finished(_anim_name):
	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	create_explosion(0, current_tile, false)
	detonate()
	emit_signal("exploded")
	queue_free()


func create_explosion(anim_type, tile, exp_rotate):
	var explosion = preload("res://Scenes/explosion.tscn").instantiate()
	explosion.global_position = tile_map.map_to_local(tile)
	explosion.explosion_rotate = exp_rotate
	explosion.anim_type = anim_type 
	call_deferred("_add_explosion", explosion)

func _add_explosion(explosion):
	manager.add_child(explosion)


func detonate():
	
	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	
	for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for i in range(1, explosion_len + 1):
			var new_tile = current_tile + direction * i
			if canExplode(new_tile):
				# x = 0 - Horizontal
				# y = 0 - Vertical
				if direction.x == 0:
					if i == explosion_len:
						if direction.y < 0:
							create_explosion(4, new_tile, true)
						else:
							create_explosion(4, new_tile, false)
					else:
						if direction.y < 0:
							create_explosion(3, new_tile, true)
						else:
							create_explosion(3, new_tile, false)
				else:
					if i == explosion_len:
						if direction.x < 0:
							create_explosion(2, new_tile, true)
						else:
							create_explosion(2, new_tile, false)
					else:
						if direction.x < 0:
							create_explosion(1, new_tile, true)
						else:
							create_explosion(1, new_tile, false)
			else:
				break


func canExplode(tile):
	var tile_data: TileData = tile_map.get_cell_tile_data(0, tile)
	var tile_data_layer1: TileData = tile_map.get_cell_tile_data(1, tile)
	
	if tile_data.get_custom_data("walkable"):
		if tile_data_layer1 != null and tile_data_layer1.get_custom_data("breakable"):
			#break_block(tile, Time.get_unix_time_from_system())
			call_deferred("break_block", tile)
		else:
			return true
	else:
		return false

func break_block(tile):
	
	tile_map.erase_cell(1, tile)
	
	var chance = rng.randf()
	var type = rng.randf()
	if chance > 0.7:
		var power_up = preload("res://Scenes/power_ups.tscn").instantiate()
		power_up.type = type
		power_up.global_position = tile_map.map_to_local(tile)
		call_deferred("_add_power_up", power_up)

func _add_power_up(power_up):
	manager_power_up.add_child(power_up)

func _on_area_2d_area_entered(area):
	if area.get_collision_layer() == 2:
		anim.stop()
		var current_tile: Vector2i = tile_map.local_to_map(global_position)
		create_explosion(0, current_tile, false)
		detonate()
		emit_signal("exploded")
		queue_free()
