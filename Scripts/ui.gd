extends CanvasLayer

# ── Exports ───────────────────────────────────────────────────────────────────
@export var max_energy:   float = 100.0
@export var initial_time: float = 240.0  # seconds

# ── Onready ──────────────────────────────────────────────────────────────────
@onready var bar:    ProgressBar     = $FlashlightBar
@onready var timer:  Label           = $TimerLabel
@onready var player: CharacterBody2D = get_node("../Player")

# ── State ─────────────────────────────────────────────────────────────────────
var time_left:     float = 0.0
var timer_running: bool  = false

func _ready() -> void:
	# configure energy bar
	bar.min_value = 0
	bar.max_value = max_energy
	bar.value     = max_energy

	# set up countdown but don't start it
	time_left = initial_time
	_update_timer_label()

func start_timer() -> void:
	timer_running = true

func _process(_delta: float) -> void:
	# only count down once Enter has been pressed
	if timer_running and time_left > 0.0:
		time_left = max(time_left - _delta, 0.0)
		_update_timer_label()

		if time_left <= 30.0:
			if int(time_left * 2) % 2 == 0:
				timer.modulate = Color(1, 0, 0)
			else:
				timer.modulate = Color(1, 1, 1)
		else:
			timer.modulate = Color(1, 1, 1)

		if time_left == 0.0:
			get_tree().quit()

	# always reflect the player's current energy
	bar.value = player.energy

func _update_timer_label() -> void:
	var m = int(time_left / 60)
	var s = int(time_left) % 60
	timer.text = "%d:%02d" % [m, s]

func set_energy(energy_val: float) -> void:
	bar.value = energy_val
