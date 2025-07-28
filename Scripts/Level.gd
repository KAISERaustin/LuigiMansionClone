extends Node2D

# ── Onready references ────────────────────────────────────────────────────────
@onready var floor_layer: TileMapLayer     = $TileMapLayerFloors
@onready var wall_layer:  TileMapLayer     = $TileMapLayerWalls
@onready var mid_layer:   TileMapLayer     = $TileMapLayerMid
@onready var player:      CharacterBody2D = $Player
@onready var ui:          CanvasLayer     = $UI

# ── PackedScene & State ──────────────────────────────────────────────────────
const EnergyPickupScene: PackedScene = preload("res://scenes/EnergyPickup.tscn")
var spawn_positions: Array[Vector2i] = []
var current_pickup:   Node          = null
var respawn_timer:    Timer         = null
var game_started:     bool          = false

func _ready() -> void:
	randomize()
	_populate_spawn_positions()
	# hide the player until Enter is pressed
	player.visible = false

func _input(event: InputEvent) -> void:
	if not game_started and event.is_action_pressed("ui_accept"):
		_start_game()

func _start_game() -> void:
	game_started = true

	# show & position player
	player.visible = true
	_spawn_player()

	# spawn the first energy pickup
	spawn_energy_pickup()

	# kick off the UI countdown
	ui.start_timer()

	# prepare (but do not start) the 15s respawn timer
	respawn_timer = Timer.new()
	respawn_timer.wait_time = 15.0
	respawn_timer.one_shot  = false
	add_child(respawn_timer)
	respawn_timer.timeout.connect(Callable(self, "_on_respawn_timer_timeout"))

func _spawn_player() -> void:
	if spawn_positions.is_empty():
		return

	# pick the top-left valid floor cell
	var top_left := spawn_positions[0]
	for cell in spawn_positions:
		if cell.y < top_left.y or (cell.y == top_left.y and cell.x < top_left.x):
			top_left = cell

	var world := floor_layer.to_global(floor_layer.map_to_local(top_left))
	player.global_position = world

func _populate_spawn_positions() -> void:
	spawn_positions.clear()
	for cell in floor_layer.get_used_cells():
		if wall_layer.get_cell_source_id(cell) == -1 \
		and mid_layer.get_cell_source_id(cell)  == -1:
			spawn_positions.append(cell)

func spawn_energy_pickup() -> void:
	if current_pickup and is_instance_valid(current_pickup):
		return
	if spawn_positions.is_empty():
		return

	var cell  := spawn_positions[randi() % spawn_positions.size()]
	var world := floor_layer.to_global(floor_layer.map_to_local(cell))
	var pickup := EnergyPickupScene.instantiate()
	pickup.position = world
	pickup.body_entered.connect(Callable(self, "_on_pickup_collected"))
	add_child(pickup)
	current_pickup = pickup

func _on_pickup_collected(_body: Node) -> void:
	# only start the loop once after the first collection
	if respawn_timer and respawn_timer.is_stopped():
		respawn_timer.start()

func _on_respawn_timer_timeout() -> void:
	if not current_pickup or not is_instance_valid(current_pickup):
		spawn_energy_pickup()
