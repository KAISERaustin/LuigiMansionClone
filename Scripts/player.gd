# res://scripts/player.gd
extends CharacterBody2D

signal energy_changed(new_energy)

@export var speed: float                   = 200.0
@export var max_energy: float              = 100.0
@export var depletion_rate: float          = 10.0
@export var animated_sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var flashlight_path:    NodePath   = NodePath("Flashlight2D")

@onready var animated_sprite: AnimatedSprite2D = get_node(animated_sprite_path)
@onready var flashlight:      PointLight2D      = get_node(flashlight_path)

var last_direction: String
var energy:              float
var base_light_energy:   float
var initial_tex_scale:   float
var half_tex_width:      float

func _ready() -> void:
	last_direction    = "down"
	energy            = max_energy
	base_light_energy = flashlight.energy
	initial_tex_scale = flashlight.texture_scale
	var tex = flashlight.texture as Texture2D
	half_tex_width    = tex.get_width() * 0.5

func _physics_process(_delta: float) -> void:
	if is_multiplayer_authority():
		# ── Movement & Animation ───────────────────────────────────────────────
		var input_vec = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
		)
		if input_vec != Vector2.ZERO:
			velocity = input_vec.normalized() * speed
			_play_walk_animation(input_vec)
		else:
			velocity = Vector2.ZERO
			_play_idle_animation()

		# ── Aim Flashlight ─────────────────────────────────────────────────────
		var aim = (get_global_mouse_position() - global_position).angle()
		flashlight.rotation = aim

		move_and_slide()

		# ── Network: send position + beam direction ───────────────────────────
		rpc("rpc_sync_transform", global_position, aim)

func _process(_delta: float) -> void:
	if is_multiplayer_authority():
		var enabled_state := false
		var ratio := 0.0

		if Input.is_key_pressed(KEY_B) and energy > 0.0:
			energy = max(energy - depletion_rate * _delta, 0.0)
			emit_signal("energy_changed", energy)
			ratio = energy / max_energy
			enabled_state = true

			# Locally apply scale, brightness, offset
			flashlight.texture_scale = initial_tex_scale * ratio
			flashlight.energy        = base_light_energy   * ratio
			flashlight.offset.x      = half_tex_width      * ratio

		flashlight.enabled = enabled_state
		# Mirror flashlight state to other peers
		rpc("rpc_update_flashlight", ratio, enabled_state)
	# non-authority peers will only receive via RPC

# ── RPCs ───────────────────────────────────────────────────────────────────────

@rpc("any_peer", "unreliable")
func rpc_sync_transform(pos: Vector2, beam_rot: float) -> void:
	if not is_multiplayer_authority():
		global_position    = pos
		# apply remote’s beam direction
		flashlight.rotation = beam_rot

@rpc("any_peer", "unreliable")
func rpc_update_flashlight(ratio: float, enabled_state: bool) -> void:
	if not is_multiplayer_authority():
		flashlight.texture_scale = initial_tex_scale * ratio
		flashlight.energy        = base_light_energy   * ratio
		flashlight.offset.x      = half_tex_width      * ratio
		flashlight.enabled       = enabled_state

# ── Animation Helpers ─────────────────────────────────────────────────────────

func _play_walk_animation(direction: Vector2) -> void:
	if abs(direction.x) > abs(direction.y):
		if direction.x > 0:
			animated_sprite.play("walk_right"); last_direction = "right"
		else:
			animated_sprite.play("walk_left");  last_direction = "left"
	else:
		if direction.y > 0:
			animated_sprite.play("walk_down");  last_direction = "down"
		else:
			animated_sprite.play("walk_up");    last_direction = "up"
	animated_sprite.flip_h = false

func _play_idle_animation() -> void:
	animated_sprite.play("idle_%s" % last_direction)
