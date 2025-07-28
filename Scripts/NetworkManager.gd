# res://scripts/NetworkManager.gd
extends Node

@export var initial_time: float              = 240.0    # 4 minutes
@export var player_scene: PackedScene       = preload("res://scenes/Player.tscn")
@export var energy_pickup_scene: PackedScene = preload("res://scenes/EnergyPickup.tscn")
const PLAYER_COLORS: Array[Color] = [
	Color(1, 0, 1),  # purple
	Color(0, 1, 0),  # green
	Color(1, 0, 0),  # red
	Color(1, 1, 0)   # yellow
]

# ── State ─────────────────────────────────────────────────────────────────────
var player: CharacterBody2D    = null
var current_pickup: Node       = null
var time_left:        float    = 0.0
var game_started:     bool     = false
var respawn_timer:    Timer

func _ready() -> void:
	# Set up the 15s respawn timer
	respawn_timer = Timer.new()
	respawn_timer.wait_time  = 15.0
	respawn_timer.one_shot   = true
	respawn_timer.autostart  = false
	add_child(respawn_timer)
	respawn_timer.timeout.connect(_on_respawn_timeout)

	_spawn_player()

func _process(delta: float) -> void:
	# Start game on Enter
	if not game_started and Input.is_action_just_pressed("ui_accept"):
		start_game()

	# Countdown timer
	if game_started and time_left > 0.0:
		time_left = max(time_left - delta, 0.0)
		var sec = int(time_left)
		# Update UI (assumes a UI CanvasLayer with set_timer)
		var ui = get_tree().current_scene.get_node("UI")
		ui.set_timer(sec)
		if time_left == 0.0:
			get_tree().quit()

func start_game() -> void:
	game_started = true
	time_left    = initial_time
	_spawn_pickup()

# ── Spawn Helpers ──────────────────────────────────────────────────────────────
func _spawn_player() -> void:
	var level = get_tree().current_scene
	player = player_scene.instantiate() as CharacterBody2D
	player.name     = "Player"
	player.position = Vector2.ZERO
	level.add_child(player)

func _spawn_pickup() -> void:
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

func _do_spawn_pickup(pos: Vector2) -> void:
	if current_pickup:
		current_pickup.queue_free()

	current_pickup = energy_pickup_scene.instantiate()
	current_pickup.position = pos
	current_pickup.connect("body_entered", Callable(self, "_on_pickup_body_entered"))
	get_tree().current_scene.add_child(current_pickup)

func _on_pickup_body_entered(body: Node) -> void:
	if body is CharacterBody2D and player:
		# Remove pickup
		current_pickup.queue_free()
		current_pickup = null
		# Credit the player
		player.energy = min(player.energy + 30, player.max_energy)
		player.emit_signal("energy_changed", player.energy)
		# Start respawn timer
		respawn_timer.start()

func _on_respawn_timeout() -> void:
	if current_pickup == null:
		_spawn_pickup()
