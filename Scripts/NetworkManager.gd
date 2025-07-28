# res://scripts/NetworkManager.gd
extends Node

@export var port: int                         = 12345
@export var initial_time: float               = 240.0    # 4 minutes
@export var player_scene: PackedScene         = preload("res://scenes/Player.tscn")
@export var energy_pickup_scene: PackedScene  = preload("res://scenes/EnergyPickup.tscn")

const PLAYER_COLORS: Array[Color] = [
	Color(1, 0, 1),  # purple
	Color(0, 1, 0),  # green
	Color(1, 0, 0),  # red
	Color(1, 1, 0)   # yellow
]

# ── State ───────────────────────────────────────────────────────────────────────
var players:    Dictionary[int, CharacterBody2D] = {}
var current_pickup: Node                        = null

var time_left:           float = 0.0
var _last_broadcast_sec: int   = -1
var game_started:        bool  = false

var respawn_timer: Timer

# ── Initialization ─────────────────────────────────────────────────────────────
func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# Create a 15 s one-shot timer for respawns (host only will start it)
	respawn_timer = Timer.new()
	respawn_timer.wait_time  = 15.0
	respawn_timer.one_shot   = true
	respawn_timer.autostart  = false
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timeout)

func _process(delta: float) -> void:
	# 1) Host presses Enter to start the match (once)
	if is_multiplayer_authority() and not game_started and Input.is_action_just_pressed("ui_accept"):
		start_game()

	# 2) Host-only match timer (once started)
	if is_multiplayer_authority() and game_started and time_left > 0.0:
		time_left = max(time_left - delta, 0.0)
		var sec = int(time_left)
		if sec != _last_broadcast_sec:
			_last_broadcast_sec = sec
			rpc("rpc_update_timer", sec)
		if time_left == 0.0:
			rpc("rpc_end_game")
			get_tree().quit()

# ── Public API ──────────────────────────────────────────────────────────────────
func start_server() -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(port)
	multiplayer.multiplayer_peer = peer
	print("Server started on port %d" % port)

	# Spawn the host’s own player avatar
	_spawn_player(multiplayer.get_unique_id())

func connect_to_server(address: String) -> void:
	var peer = ENetMultiplayerPeer.new()
	peer.create_client(address, port)
	multiplayer.multiplayer_peer = peer
	print("Connecting to %s:%d…" % [address, port])

func start_game() -> void:
	# Host only, once
	if not is_multiplayer_authority() or game_started:
		return
	game_started = true
	time_left    = initial_time
	_last_broadcast_sec = -1
	call_deferred("_broadcast_initial_timer")
	_spawn_pickup_on_host()

func _broadcast_initial_timer() -> void:
	rpc("rpc_update_timer", int(time_left))

# ── Multiplayer Callbacks ──────────────────────────────────────────────────────
func _on_peer_connected(id: int) -> void:
	# Host tells newcomer about current state
	if is_multiplayer_authority():
		_spawn_player(id)
		for eid in players.keys():
			rpc_id(id, "rpc_spawn_player", eid)
		if game_started and current_pickup:
			rpc_id(id, "rpc_spawn_pickup", current_pickup.position)
			rpc_id(id, "rpc_update_timer", int(time_left))

func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		players[id].queue_free()
		players.erase(id)

func _on_connected_to_server() -> void:
	_spawn_player(multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	print("Connection to server failed.")

# ── RPCs ───────────────────────────────────────────────────────────────────────
@rpc("any_peer")
func rpc_spawn_player(peer_id: int) -> void:
	_spawn_player(peer_id)

@rpc("any_peer")
func rpc_spawn_pickup(pos: Vector2) -> void:
	# Clients mirror the exact host‐chosen position
	if not is_multiplayer_authority():
		_do_spawn_pickup(pos)

@rpc("any_peer")
func rpc_remove_pickup() -> void:
	if current_pickup:
		current_pickup.queue_free()
		current_pickup = null

@rpc("any_peer", "reliable")
func rpc_update_timer(seconds_left: int) -> void:
	var ui = get_tree().current_scene.get_node("UI") as CanvasLayer
	ui.set_timer(seconds_left)

@rpc("any_peer", "reliable")
func rpc_end_game() -> void:
	get_tree().quit()

@rpc("any_peer", "reliable")
func rpc_collect_pickup(picker_id: int) -> void:
	# Any peer (client or host) can call this; only host executes
	if not is_multiplayer_authority():
		return
	# 1) Remove and notify everyone
	if current_pickup:
		current_pickup.queue_free()
		current_pickup = null
	rpc("rpc_remove_pickup")
	# 2) Credit battery
	var collector = players.get(picker_id)
	if collector:
		collector.energy = min(collector.energy + 30, collector.max_energy)
		collector.emit_signal("energy_changed", collector.energy)
	# 3) Start the 15 s respawn timer (host only)
	respawn_timer.start()

# ── Spawn Helpers ──────────────────────────────────────────────────────────────
func _spawn_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var ids = multiplayer.get_peers().duplicate()
	ids.append(multiplayer.get_unique_id())
	ids.sort()
	var idx = ids.find(peer_id) % PLAYER_COLORS.size()

	var level       = get_tree().current_scene
	var flr_layer   = level.get_node("TileMapLayerFloors") as TileMapLayer
	var ur          = flr_layer.get_used_rect()
	var corners = [
		Vector2i(ur.position.x,                         ur.position.y),
		Vector2i(ur.position.x + ur.size.x - 1,         ur.position.y),
		Vector2i(ur.position.x,                         ur.position.y + ur.size.y - 1),
		Vector2i(ur.position.x + ur.size.x - 1,         ur.position.y + ur.size.y - 1),
	]
	var wpos = flr_layer.to_global(flr_layer.map_to_local(corners[idx]))

	var p = player_scene.instantiate() as CharacterBody2D
	p.name                        = "Player_%d" % peer_id
	p.set_multiplayer_authority(peer_id)
	p.position                    = wpos
	p.modulate                    = PLAYER_COLORS[idx]
	level.add_child(p)
	players[peer_id] = p

	if peer_id == multiplayer.get_unique_id():
		var ui = level.get_node("UI") as CanvasLayer
		p.connect("energy_changed", Callable(ui, "_on_player_energy_changed"))
		ui._on_player_energy_changed(p.energy)

func _spawn_pickup_on_host() -> void:
	# Host chooses random free floor cell, spawns & broadcasts
	if not is_multiplayer_authority():
		return
	var level     = get_tree().current_scene
	var flr_layer = level.get_node("TileMapLayerFloors") as TileMapLayer
	var mid_layer = level.get_node("TileMapLayerMid")    as TileMapLayer

	var free_cells = flr_layer.get_used_cells().filter(func(c):
		return mid_layer.get_cell_tile_data(c) == null
	)
	if free_cells.is_empty():
		return

	var cell = free_cells[randi() % free_cells.size()]
	var pos  = flr_layer.to_global(flr_layer.map_to_local(cell))

	_do_spawn_pickup(pos)
	rpc("rpc_spawn_pickup", pos)

func _do_spawn_pickup(pos: Vector2) -> void:
	if current_pickup:
		current_pickup.queue_free()
	current_pickup = energy_pickup_scene.instantiate()
	current_pickup.position = pos
	current_pickup.connect("body_entered", Callable(self, "_on_pickup_body_entered"))
	get_tree().current_scene.add_child(current_pickup)

func _on_pickup_body_entered(body: Node) -> void:
	# ANY peer detecting a collision locally tells the host
	if body is CharacterBody2D:
		var picker_id = body.get_multiplayer_authority()
		rpc("rpc_collect_pickup", picker_id)

func _on_respawn_timeout() -> void:
	# After 15s, host spawns the next pickup (if none)
	if is_multiplayer_authority() and current_pickup == null:
		_spawn_pickup_on_host()
