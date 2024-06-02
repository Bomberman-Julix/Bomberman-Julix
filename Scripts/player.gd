extends Node2D

@onready var sprite = $Sprite2D
@onready var animation = $AnimationPlayer
@onready var world = $"../../"
@onready var raycast = $RayCast2D
@onready var collision = $Area2D/CollisionShape2D


@export var id = 0
@export var char_name = "Name"
@export var tile_map = 0
@export var bomb_manager = 0
@export var skin = "res://Sprites/playersheet2.png"
@export var spawn_point: Vector2i = Vector2i(1, 1)


var side
var is_moving = false
var speed = 1
var bomb_count = 1
var bomb_range = 1
var bombed = false
var active = true
signal dead


func _enter_tree():
	$MultiplayerSynchronizer.set_multiplayer_authority(str(name).to_int())

func _ready():
	sprite.texture = load(skin)
	init_player()


func init_player():
	self.global_position = tile_map.map_to_local(spawn_point)
	self.collision.disabled = false
	active = true
	speed = 1
	bomb_count = 1
	bomb_range = 1
	GameManager.dead_count = 0
	animation.play("idle_down")
	self.show()


func _physics_process(_delta):
	if not active:
		return
	
	if is_moving == false:
		if side == 0:
			animation.play("idle_down")
		elif side == 1:
			animation.play("idle_right")
		elif side == 2:
			animation.play("idle_up")
	else:
		if side == 0:
				animation.play("walk_down")
		elif side == 1:
				animation.play("walk_right")
		elif side == 2:
				animation.play("walk_up")
	
	sprite.global_position = sprite.global_position.move_toward(global_position, speed)
	
	if global_position == sprite.global_position:
		is_moving = false


func _process(_delta):
	
	if not $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		return
	
	if active == false:
		return
	
	if Input.is_action_pressed("place_bomb") and !bombed and bomb_count > 0:
		var current_tile: Vector2i = tile_map.local_to_map(global_position)
		var bomb_seed = Time.get_unix_time_from_system()
		place_bomb.rpc(bomb_range, bomb_seed)
		bomb_count -= 1
		bombed = true
	elif not Input.is_action_pressed("place_bomb"):
		bombed = false
	
	if is_moving:
		return
		
	if Input.is_action_pressed("up"):
		sprite.flip_h = false
		side = 2
		move(Vector2.UP)
	elif Input.is_action_pressed("down"):
		sprite.flip_h = false
		side = 0
		move(Vector2.DOWN)
	elif Input.is_action_pressed("right"):
		sprite.flip_h = false
		side = 1
		animation.play("walk_right")
		move(Vector2.RIGHT)
	elif Input.is_action_pressed("left"):
		sprite.flip_h = true
		side = 1
		move(Vector2.LEFT)

func move(direction: Vector2):

	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	var target_tile: Vector2i = Vector2i(current_tile.x + direction.x, current_tile.y + direction.y)
	var tile_data: TileData = tile_map.get_cell_tile_data(0, target_tile)
	var tile_data_layer1: TileData = tile_map.get_cell_tile_data(1, target_tile)

	if tile_data.get_custom_data("walkable") == false:
		return
	
	raycast.target_position = direction * 16
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		return
	
	if tile_data_layer1 != null and tile_data_layer1.get_custom_data("walkable") == false:
		return
	
	# Move Player
	is_moving = true
	global_position = tile_map.map_to_local(target_tile)
	sprite.global_position = tile_map.map_to_local(current_tile)

@rpc("any_peer", "call_local", "reliable")
func place_bomb(bomb_range, bomb_seed):
	var bomb = preload("res://Scenes/bomb.tscn").instantiate()
	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	bomb.global_position = tile_map.map_to_local(current_tile)
	bomb.tile_map = tile_map
	bomb.explosion_len = bomb_range
	bomb.seed = bomb_seed
	bomb.connect("exploded", _replace_bomb)
	bomb_manager.add_child(bomb)


func _on_area_2d_area_entered(area):
	if area.get_collision_layer() == 2:
		active = false
		animation.play("death")
	
	if area.get_collision_layer() == 8:
		if area.type == 0:
			speed += 1
		elif area.type == 1:
			bomb_count += 1
		elif area.type == 2:
			bomb_range += 1
		elif area.type == 3 and speed > 1:
			speed -= 1

func _replace_bomb():
	bomb_count += 1


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "death" and multiplayer.get_unique_id() == $MultiplayerSynchronizer.get_multiplayer_authority():
		increase_dead.rpc()
		self.hide()
		collision.disabled = true
		#if get_multiplayer_authority() == multiplayer.get_unique_id():

@rpc("any_peer", "call_local", "reliable")
func increase_dead():
	if multiplayer.is_server():
		GameManager.dead_count += 1
		if GameManager.dead_count == GameManager.Players.size() - 1:
			emit_signal("dead")
