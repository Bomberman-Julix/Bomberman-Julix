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
	#Inicia o player
	init_player()


func init_player():
	#Coloca o player no spawn
	self.global_position = tile_map.map_to_local(spawn_point)
	#Abilita a colisão
	self.collision.disabled = false
	#Ativa o player
	active = true
	#Reseta os status
	speed = 1
	bomb_count = 1
	bomb_range = 1
	GameManager.dead_count = 0
	animation.play("idle_down")
	#Mostra o player
	self.show()


func _physics_process(_delta):
	if not active:
		return
	
	#Verifica se o player está se movendo
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
	
	#Iguala as posições da sprite e do player
	sprite.global_position = sprite.global_position.move_toward(global_position, speed)
	
	if global_position == sprite.global_position:
		is_moving = false


func _process(_delta):
	#Verifica se o Player é o Player
	if not $MultiplayerSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id():
		return
	
	#Verifica se o Player está ativo
	if active == false:
		return
	
	#Pega o tile e que está e seus dados
	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	var tile_data: TileData = tile_map.get_cell_tile_data(1, current_tile)
	#Verifica se o player está em um tile "ilegal"
	if tile_data != null and tile_data.get_custom_data("walkable") == false:
		#Se estiver dentro ele morre
		active = false
		animation.play("death")
	
	# Coloca a bomba
	if Input.is_action_pressed("place_bomb") and !bombed and bomb_count > 0:
		var bomb_seed = Time.get_unix_time_from_system()
		place_bomb.rpc(bomb_range, bomb_seed)
		bomb_count -= 1
		bombed = true
	elif not Input.is_action_pressed("place_bomb"):
		bombed = false
	
	#Verifica se está se movendo
	if is_moving:
		return
	
	#Move para cima
	if Input.is_action_pressed("up"):
		sprite.flip_h = false
		side = 2
		move(Vector2.UP)
	#Move para baixo
	elif Input.is_action_pressed("down"):
		sprite.flip_h = false
		side = 0
		move(Vector2.DOWN)
	#Move para direita
	elif Input.is_action_pressed("right"):
		sprite.flip_h = false
		side = 1
		animation.play("walk_right")
		move(Vector2.RIGHT)
	#Move para esquerda
	elif Input.is_action_pressed("left"):
		sprite.flip_h = true
		side = 1
		move(Vector2.LEFT)

#Função que move o player
func move(direction: Vector2):

	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	var target_tile: Vector2i = Vector2i(current_tile.x + direction.x, current_tile.y + direction.y)
	var tile_data: TileData = tile_map.get_cell_tile_data(0, target_tile)
	var tile_data_layer1: TileData = tile_map.get_cell_tile_data(1, target_tile)
	
	#Verifica se o tile que irá se mover é "legal"
	if tile_data == null:
		active = false
		animation.play("death") 
	elif tile_data.get_custom_data("walkable") == false:
		return
	
	#Força a atualização do raycast
	raycast.target_position = direction * 16
	raycast.force_raycast_update()
	
	#Verifiac colisão
	if raycast.is_colliding():
		return
	
	if tile_data_layer1 != null and tile_data_layer1.get_custom_data("walkable") == false:
		return
	
	# Move o Player
	is_moving = true
	global_position = tile_map.map_to_local(target_tile)
	sprite.global_position = tile_map.map_to_local(current_tile)

#Função de colocar a bomba
@rpc("any_peer", "call_local", "reliable")
func place_bomb(bomb_range, bomb_seed):
	var bomb = preload("res://Scenes/bomb.tscn").instantiate()
	var current_tile: Vector2i = tile_map.local_to_map(global_position)
	#Posição da bomba
	bomb.global_position = tile_map.map_to_local(current_tile)
	bomb.tile_map = tile_map
	#Range da bomba
	bomb.explosion_len = bomb_range
	#Seed da bomba
	bomb.seed = bomb_seed
	bomb.connect("exploded", _replace_bomb)
	bomb_manager.add_child(bomb)


func _on_area_2d_area_entered(area):
	# Se entrar na area da explosão morre
	if area.get_collision_layer() == 2:
		active = false
		animation.play("death")
	
	#Se entrar na area do power up atualiza os status
	if area.get_collision_layer() == 8:
		if area.type == 0:
			speed += 1
		elif area.type == 1:
			bomb_count += 1
		elif area.type == 2:
			bomb_range += 1
		elif area.type == 3 and speed > 1:
			speed -= 1

#Recoloca a bomba
func _replace_bomb():
	bomb_count += 1


func _on_animation_player_animation_finished(anim_name):
	#Quando a animação de morte acaba manda um sinal para a cena do jogo
	if anim_name == "death" and multiplayer.get_unique_id() == $MultiplayerSynchronizer.get_multiplayer_authority():
		increase_dead.rpc()
		self.hide()
		collision.disabled = true

@rpc("any_peer", "call_local", "reliable")
func increase_dead():
	if multiplayer.is_server():
		GameManager.dead_count += 1
		if GameManager.dead_count == GameManager.Players.size() - 1:
			emit_signal("dead")
