extends CPUParticles2D
## +10(최대 강화) 달성 시 터지는 반짝이 이펙트. 파티클이 다 끝나면 스스로 사라진다.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	emitting = true
	await get_tree().create_timer(lifetime + 0.2).timeout
	queue_free()
