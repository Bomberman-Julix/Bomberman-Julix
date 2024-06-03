extends Node2D


@onready var player_manager = $PlayerManager
@onready var power_ups = $PowerUpManager
@onready var bomb_manager = $BombManager
@onready var scores = [$Board/P1, $Board/P2, $Board/P3, $Board/P4, $Board/P5, $Board/P6]
@onready var timer_label = $Board/TimerLabel
@onready var timer = $Board/Timer
@onready var s_timer = $GameStart
@onready var tile_map = $TileMap


@export var player_scene: PackedScene
@export var RedClr: Color
@export var OrigClr: Color
@export var map_seed = 0


signal game_ended
signal winner

var finish = false
var started = false
var spawn_locations = [Vector2i(1, 1), Vector2i(1, 13), Vector2i(13, 1), Vector2i(13, 13)]
var skins = ["res://Sprites/playersheet1.png",
"res://Sprites/playersheet2.png",
"res://Sprites/playersheet3.png",
"res://Sprites/playersheet4.png",
"res://Sprites/playersheet5.png",
"res://Sprites/playersheet6.png"]
var rng = RandomNumberGenerator.new()
var tile_map_size = 15


func _ready():
	
	rng.seed = map_seed
	build_map(tile_map_size, tile_map_size)
	
	var index = 0
	for i in GameManager.Players:
		create_players(i, index)
		index += 1
	
	started = true


@rpc("any_peer", "call_local")
func restart(seed):
	
	rng.seed = seed
	tile_map_size = 15
	build_map(tile_map_size, tile_map_size)
	
	for i in range(0, power_ups.get_child_count()):
		power_ups.get_child(i).queue_free()
	
	var index = 0
	for p in player_manager.get_children():
		p.init_player()
		scores[index].text = str(GameManager.Players[p.name.to_int()].score)
		index += 1
	
	started = true


func _on_game_start_timeout():
	if multiplayer.is_server():
		restart.rpc(Time.get_unix_time_from_system())


func create_players(i, index):
	var current_player = player_scene.instantiate()
	current_player.name = str(GameManager.Players[i].id)
	current_player.tile_map = tile_map
	current_player.bomb_manager = bomb_manager
	current_player.spawn_point = spawn_locations[index]
	current_player.skin = skins[index]
	current_player.connect("dead", _player_died)
	scores[index].show()
	scores[index].text = str(GameManager.Players[i].score)
	player_manager.add_child(current_player)


func build_map(width, height):
	
	var spawn_points = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
	Vector2i(1, 13), Vector2i(1, 12), Vector2i(2, 13),
	Vector2i(13, 1), Vector2i(12, 1), Vector2i(13, 2),
	Vector2i(13, 13), Vector2i(12, 13), Vector2i(13, 12),
	Vector2i(13, 13), Vector2i(12, 13), Vector2i(13, 12),
	Vector2i(13, 13), Vector2i(12, 13), Vector2i(13, 12)]
	
	tile_map.clear_layer(1)
	
	for x in range(1, width - 1):
		for y in range(1, height - 1):
			var chance = rng.randi_range(0, 99)
			for i in spawn_points:
				if Vector2i(x, y) == i or tile_map.get_cell_atlas_coords(0, Vector2i(x, y), 0) == Vector2i(1, 0):
					chance = -1
			if chance > 30:
				tile_map.set_cell(1, Vector2i(x, y), 0, Vector2i(0, 0))


func _process(_delta):
	if not started:
		return
	
	timer_label.text = str(ceil(timer.time_left))
	
	if timer.time_left <= 5:
		timer_label.modulate = RedClr


func _player_died():
	var id
	for p in player_manager.get_children():
		if p.active:
			id = str(p.name).to_int()
	
	GameManager.Players[id].score += 1
	if GameManager.Players[id].score == GameManager.win_con:
		emit_signal("winner", GameManager.Players[id].name)
	else:
		increase_score.rpc(id)
		s_timer.start()


@rpc("any_peer")
func increase_score(id):
	GameManager.Players[id].score += 1

var beggining = 0
var tile_id = 1
func _on_timer_timeout():
	tile_map_size -= 1
	beggining += 1
	
	for x in range(beggining, tile_map_size):
		tile_map.set_cell(1, Vector2i(beggining, x), 0, Vector2i(tile_id, 0))
		tile_map.set_cell(1, Vector2i(x, beggining), 0, Vector2i(tile_id, 0))
		
		tile_map.set_cell(1, Vector2i(tile_map_size - 1, x), 0, Vector2i(tile_id, 0))
		tile_map.set_cell(1, Vector2i(x, tile_map_size - 1), 0, Vector2i(tile_id, 0))
	
	if tile_id == 1:
		tile_id = 2
	else:
		tile_id = 1
	
	if tile_map_size == 10:
		timer.stop()
		return
	else:
		timer.start(10)
