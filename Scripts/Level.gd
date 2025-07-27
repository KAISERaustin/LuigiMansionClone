# res://scripts/Level.gd
extends Node2D

# ── TileMapLayer references ────────────────────────────────────────────────────
@onready var floorLayer: TileMapLayer = $TileMapLayerFloors
@onready var wallLayer : TileMapLayer = $TileMapLayerWalls
@onready var midLayer  : TileMapLayer = $TileMapLayerMid

# ── PackedScene & Spawn List ───────────────────────────────────────────────────
const EnergyPickupScene: PackedScene = preload("res://scenes/EnergyPickup.tscn")
var spawn_positions: Array[Vector2i] = []

# ── Track the current pickup so we know if one exists ─────────────────────────
var current_pickup: Node = null

func _ready() -> void:
	randomize()
	_populate_spawn_positions()
	# Optional: spawn one immediately
	spawn_energy_pickup()
	
	NetworkManager.start_server()

	# Create & start a 15s repeating timer
	var timer = Timer.new()
	timer.wait_time = 15.0
	timer.one_shot  = false
	add_child(timer)
	timer.start()
	timer.timeout.connect(_on_respawn_timer_timeout)

func _populate_spawn_positions() -> void:
	spawn_positions.clear()
	for cell in floorLayer.get_used_cells():
		# Only if there’s no wall and no mid‐layer tile here
		if wallLayer.get_cell_source_id(cell) == -1 \
		and midLayer.get_cell_source_id(cell)   == -1:
			spawn_positions.append(cell)

func _on_respawn_timer_timeout() -> void:
	# every 15s: if our previous pickup is gone, spawn a new one
	if current_pickup == null or not is_instance_valid(current_pickup):
		spawn_energy_pickup()

func spawn_energy_pickup() -> void:
	# don’t spawn if there’s already one alive
	if current_pickup != null and is_instance_valid(current_pickup):
		return

	if spawn_positions.is_empty():
		return

	var idx  := randi() % spawn_positions.size()
	var cell := spawn_positions[idx]

	# center in the tile: map → local → global
	var local_pos = floorLayer.map_to_local(cell)
	var world_pos = floorLayer.to_global(local_pos)

	var pickup = EnergyPickupScene.instantiate()
	pickup.position = world_pos
	add_child(pickup)

	# remember it so we don’t spawn duplicates
	current_pickup = pickup
