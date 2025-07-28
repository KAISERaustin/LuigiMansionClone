extends CanvasLayer

@export var max_energy: float   = 100.0

@onready var bar:   ProgressBar = $FlashlightBar
@onready var timer: Label       = $TimerLabel

var time_left: int = 0

func _ready() -> void:
	bar.min_value = 0
	bar.max_value = max_energy
	bar.value     = max_energy
	set_timer(0)

func _process(_delta: float) -> void:
	if time_left > 0 and time_left <= 30:
		timer.modulate = Color(1,0,0) if (time_left * 2) % 2 == 0 else Color(1,1,1)
	else:
		timer.modulate = Color(1,1,1)

func set_timer(seconds_left: int) -> void:
	time_left = seconds_left
	_update_timer_label()

func _update_timer_label() -> void:
	var m = time_left / 60
	var s = time_left % 60
	timer.text = "%d:%02d" % [m, s]

func _on_player_energy_changed(energy_val: Variant) -> void:
	bar.value = energy_val
