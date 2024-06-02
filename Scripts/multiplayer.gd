extends Control

@onready var address_line = $Start/LineJoin
@onready var timer = $Timer
@onready var player_list = $Lobby/PlayersList

@export var address = "127.0.0.1"
@export var port = 8910

var peer
var is_host = false
var rng = RandomNumberGenerator.new()

func _ready():
	multiplayer.peer_connected.connect(player_connected)
	multiplayer.peer_disconnected.connect(player_disconnected)
	multiplayer.connected_to_server.connect(connected_to_server)
	multiplayer.connection_failed.connect(connection_failed)

# gets called on the server and the clients
func player_connected(id):
	print("Player Connected ", id)
	timer.start()

# gets called on the server and the clients
func player_disconnected(id):
	
	GameManager.Players.erase(id)
	print("Player Disconnected ", id)
	
	timer.start()

func connected_to_server ():
	var p_name = $Start/LineName.text
	if p_name == "":
		p_name = str("Player ", multiplayer.get_unique_id())
	send_player_info.rpc_id(1, p_name, multiplayer.get_unique_id())

# gets called only in the clients
func connection_failed ():
	print("Connection Failed")


@rpc("any_peer")
func send_player_info(name, id):
	if not GameManager.Players.has(id):
		GameManager.Players[id] = {
			"name": name,
			"id": id,
			"score": 0,
			"active": true
		}
	
	if multiplayer.is_server():
		for i in GameManager.Players:
			send_player_info.rpc(GameManager.Players[i].name, i)


func _on_host_pressed():
	var serverCert = load("res://serverCAS.crt")
	var serverKey = load("res://serverKey.key")
	
	
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 6)
	if error != OK:
		print("Cannot host: ", error)
		return
	
	peer.get_host().dtls_server_setup(TLSOptions.server(serverKey, serverCert))
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for Players!")
	var p_name = $Start/LineName.text
	if p_name == "":
		p_name = str("Player ", multiplayer.get_unique_id())
	send_player_info(p_name, multiplayer.get_unique_id())
	
	$Start.hide()
	$Lobby.show()
	$Lobby/StartGame.show()
	timer.start()

func _on_join_pressed():
	if address_line.text != "":
		address = address_line.text
	
	var serverCert = load("res://serverCAS.crt")
	
	peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	var host = str("wss://", address, ":", port)
	peer.get_host().dtls_client_setup(host, TLSOptions.client_unsafe(serverCert))
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.set_multiplayer_peer(peer)
	
	$Start.hide()
	$Lobby.show()

func _on_cancel_pressed():
	
	GameManager.Players.clear()
	peer.close()
	multiplayer.multiplayer_peer = null
	
	$Lobby.hide()
	$Start.show()
	$Lobby/StartGame.hide()


func _on_start_pressed():
	var seed = Time.get_unix_time_from_system()
	start_game.rpc(seed)

@rpc("any_peer", "call_local")
func start_game(seed):
	var game
	if GameManager.Players.size() > 4:
		game = load("res://Scenes/map_6p.tscn").instantiate()
	else:
		game = load("res://Scenes/map_4p.tscn").instantiate()
	
	game.map_seed = seed
	game.connect("winner", _end_game)
	get_tree().root.add_child(game)
	self.hide()

func _end_game(name):
	end_the_game.rpc(name)


@rpc("any_peer", "call_local")
func end_the_game(name):
	
	for i in GameManager.Players:
		if GameManager.Players[i].score == GameManager.win_con:
			print("Winner: ", name)
		GameManager.Players[i].score = 0
	
	var node = get_tree().root.get_child(2)
	get_tree().root.remove_child(node)
	DisplayServer.window_set_size(Vector2i(GameManager.screen_width * 2, GameManager.screen_height * 2))
	self.show()


func _process(_delta):
	pass



func list_players():
	for i  in range(0, player_list.get_child_count()):
		player_list.get_child(i).queue_free()
	
	for i in GameManager.Players:
		var line = Label.new()
		line.text = GameManager.Players[i].name
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		player_list.add_child(line)


func _on_timer_timeout():
	list_players()
