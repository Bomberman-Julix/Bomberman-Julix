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
	# Conecta os sinais de conexão
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

# Manda as informções do player
@rpc("any_peer")
func send_player_info(nome, id):
	if not GameManager.Players.has(id):
		GameManager.Players[id] = {
			"nome": nome,
			"id": id,
			"score": 0,
		}
	
	if multiplayer.is_server():
		for i in GameManager.Players:
			send_player_info.rpc(GameManager.Players[i].nome, i)

# Cria o host ao clicar no botão
func _on_host_pressed():
	# Carrega a chave e certificado da criptografia
	var serverCert = load("res://serverCAS.crt")
	var serverKey = load("res://serverKey.key")
	
	# Cria o host peer
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, 6)
	if error != OK:
		print("Cannot host: ", error)
		return
	
	# Aplica a criptografia
	peer.get_host().dtls_server_setup(TLSOptions.server(serverKey, serverCert))
	#Comprime a "conexão" (sei lá)
	peer.get_host().compress(ENetConnection.COMPRESS_RANGE_CODER)
	
	multiplayer.set_multiplayer_peer(peer)
	print("Waiting for Players!")
	# Pega o nome colocado no LineEdit se não pega um padrão
	var p_name = $Start/LineName.text
	if p_name == "":
		p_name = str("Player ", multiplayer.get_unique_id())
	send_player_info(p_name, multiplayer.get_unique_id())
	
	# Esconde a UI e mostra os botões de começo
	$Start.hide()
	$Lobby.show()
	$Lobby/StartGame.show()
	timer.start()

#Cria o client ao clicar no botão "join"
func _on_join_pressed():
	#Pega o IP do LineEdit
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

# Disconecta o Player ao clicar no botão "Cancel"
func _on_cancel_pressed():
	
	GameManager.Players.clear()
	peer.close()
	multiplayer.multiplayer_peer = null
	
	$Lobby.hide()
	$Start.show()
	$Lobby/StartGame.hide()

# Começa o Game ao clicar no botão "Start"
func _on_start_pressed():
	var set_seed = Time.get_unix_time_from_system()
	# Chama a função start_game em todos os peers
	start_game.rpc(set_seed)

@rpc("any_peer", "call_local")
func start_game(map_seed):
	var game
	if GameManager.Players.size() > 4 or GameManager.use_Map6:
		game = load("res://Scenes/map_6p.tscn").instantiate()
	else:
		game = load("res://Scenes/map_4p.tscn").instantiate()
	
	game.map_seed = map_seed
	game.connect("winner", _end_game)
	get_tree().root.add_child(game)
	self.hide()

func _end_game(nome):
	end_the_game.rpc(nome)


@rpc("any_peer", "call_local")
func end_the_game(nome):
	
	for i in GameManager.Players:
		if GameManager.Players[i].score == GameManager.win_con:
			print("Winner: ", nome)
		GameManager.Players[i].score = 0
	
	var node = get_tree().root.get_child(2)
	get_tree().root.remove_child(node)
	get_window().size = Vector2(288 * 2, 240 * 2)
	self.show()


func list_players():
	for i  in range(0, player_list.get_child_count()):
		player_list.get_child(i).queue_free()
	
	for i in GameManager.Players:
		var line = Label.new()
		line.text = GameManager.Players[i].nome
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		player_list.add_child(line)


func _on_timer_timeout():
	list_players()
