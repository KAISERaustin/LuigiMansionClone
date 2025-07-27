extends CanvasLayer

# ── Exports ───────────────────────────────────────────────────────────────────
@export var max_energy: float   = 100.0    # matches your player’s max_energy
@export var initial_time: float = 240.0    # 4 minutes in seconds

# ── Onready ──────────────────────────────────────────────────────────────────
@onready var bar:   ProgressBar = $FlashlightBar
@onready var timer: Label       = $TimerLabel

# ── State ─────────────────────────────────────────────────────────────────────
var time_left: float

func _ready() -> void:
	# Configure the energy bar
	bar.min_value = 0
	bar.max_value = max_energy
	bar.value     = max_energy

	# Start the countdown
	time_left = initial_time
	_update_timer_label()

func _process(delta: float) -> void:
	# 1) Countdown
	if time_left > 0.0:
		time_left = max(time_left - delta, 0.0)
		_update_timer_label()

		# 2) Flash when low (last 30 seconds)
		if time_left <= 30.0:
			# alternate color each half-second
			if int(time_left * 2) % 2 == 0:
				timer.modulate = Color(1, 0, 0)
			else:
				timer.modulate = Color(1, 1, 1)
		else:
			timer.modulate = Color(1, 1, 1)

		# 3) At zero, quit the game
		if time_left == 0.0:
			get_tree().quit()

func _update_timer_label() -> void:
	var m = int(time_left / 60)
	var s = int(time_left) % 60
	# show “4:00”, “3:59”, … “0:00”
	timer.text = "%d:%02d" % [m, s]

func _on_player_energy_changed(energy_val: Variant) -> void:
	bar.value = energy_val
