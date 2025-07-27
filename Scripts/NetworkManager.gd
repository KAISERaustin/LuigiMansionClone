# res://scripts/NetworkManager.gd
extends Node

@export var port: int = 12345

func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	# Enable high-level multiplayer
	get_tree().multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % port)

	# Connect to peer join/leave on the API
	var mp = get_tree().multiplayer
	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.server_disconnected.connect(_on_server_disconnected)

func connect_to_server(address: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	get_tree().multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%d…" % [address, port])

	var mp = get_tree().multiplayer
	mp.connected_to_server.connect(_on_connected_to_server)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)

# ————— Signal callbacks —————————————————————————————————————

func _on_peer_connected(id: int) -> void:
	print("Peer connected with ID:", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected with ID:", id)

func _on_connected_to_server() -> void:
	print("Successfully connected to server.")

func _on_connection_failed() -> void:
	print("Failed to connect to server.")

func _on_server_disconnected() -> void:
	print("Server has disconnected.")
