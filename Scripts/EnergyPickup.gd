# res://scripts/EnergyPickup.gd
extends Area2D

@export var energy_amount: float = 30.0  # how much to restore

func _on_body_entered(body: Node) -> void:
	# only affect the player
	if body is CharacterBody2D:
		var player = body as CharacterBody2D
		# restore energy and clamp
		player.energy = min(player.energy + energy_amount, player.max_energy)
		# notify UI
		player.emit_signal("energy_changed", player.energy)
		# remove the pickup
		queue_free()
