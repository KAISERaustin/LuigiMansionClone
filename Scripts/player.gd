extends CharacterBody2D

# declare your signal
signal energy_changed(energy_val: float)

# ── Exports ───────────────────────────────────────────────────────────────────
@export var speed: float                   = 200.0
@export var max_energy: float              = 100.0
@export var depletion_rate: float          = 10.0
@export var animated_sprite_path: NodePath = NodePath("AnimatedSprite2D")
@export var flashlight_path:    NodePath   = NodePath("Flashlight2D")

# ── Onready & State ────────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = get_node(animated_sprite_path)
@onready var flashlight:       PointLight2D    = get_node(flashlight_path)

var last_direction: String
var energy:         float
var base_light_energy: float
var initial_tex_scale: float
var half_tex_width:    float

func _ready() -> void:
	last_direction    = "down"
	energy            = max_energy
	base_light_energy = flashlight.energy
	initial_tex_scale = flashlight.texture_scale

	var tex := flashlight.texture as Texture2D
	half_tex_width = tex.get_width() * 0.5

func _physics_process(_delta: float) -> void:
	var input_vec := Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down")  - Input.get_action_strength("ui_up")
	)

	if input_vec != Vector2.ZERO:
		velocity = input_vec.normalized() * speed
		_play_walk_animation(input_vec)
	else:
		velocity = Vector2.ZERO
		_play_idle_animation()

	flashlight.rotation = (get_global_mouse_position() - global_position).angle()
	move_and_slide()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_B) and energy > 0.0:
		energy = max(energy - depletion_rate * delta, 0.0)
		var ratio := energy / max_energy

		flashlight.texture_scale = initial_tex_scale * ratio
		flashlight.energy        = base_light_energy * ratio
		flashlight.offset.x      = half_tex_width * ratio
		flashlight.enabled       = true

		# emit from inside this class so Godot sees the signal “used”
		emit_signal("energy_changed", energy)

		if energy == 0.0:
			flashlight.enabled = false
	else:
		flashlight.enabled = false

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
