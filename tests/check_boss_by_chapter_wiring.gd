extends Node
## enemy.gd의 BOSS_BY_CHAPTER(장 -> kind_id)가 실제 스폰 경로(_ready ->
## _apply_kind)에서 그 장에 맞는 텍스처/틴트/이름표로 이어지는지 확인한다.
## check_second_job_fx_wiring.gd와 같은 패턴: 정적 딕셔너리끼리 비교하지
## 않고, is_boss=true인 enemy.tscn을 각 장 번호로 실제로 스폰해 Sprite
## 노드에 실제로 적용된 값을 읽는다.

const EnemyScript := preload("res://scripts/enemy.gd")

func _ready() -> void:
	var ok := true

	for chapter in EnemyScript.BOSS_BY_CHAPTER.keys():
		var kind_id: String = EnemyScript.BOSS_BY_CHAPTER[chapter]
		var expected: Dictionary = EnemyScript.KINDS[kind_id]

		GameState.reset()
		GameState.chapter = chapter
		var enemy: CharacterBody2D = preload("res://scenes/enemy.tscn").instantiate()
		enemy.is_boss = true
		add_child(enemy)
		await get_tree().physics_frame

		var sprite: Sprite2D = enemy.get_node("Sprite")
		ok = _check("%d장(%s) kind_id 해석" % [chapter, kind_id],
			enemy.kind.get("id") == kind_id) and ok
		ok = _check("%d장(%s) 텍스처가 %s로 실제 연결" % [chapter, kind_id, expected["texture"]],
			sprite.texture != null and sprite.texture.resource_path == expected["texture"]) and ok
		ok = _check("%d장(%s) hframes/vframes 실제 적용" % [chapter, kind_id],
			sprite.hframes == expected["hframes"] and sprite.vframes == expected["vframes"]) and ok
		ok = _check("%d장(%s) 스프라이트 실제 프레임 크기가 hframes/vframes와 나누어떨어짐" % [chapter, kind_id],
			int(sprite.texture.get_width()) % int(expected["hframes"]) == 0
			and int(sprite.texture.get_height()) % int(expected["vframes"]) == 0) and ok
		ok = _check("%d장(%s) tint가 실제로 modulate에 적용" % [chapter, kind_id],
			sprite.modulate.is_equal_approx(expected.get("tint", Color.WHITE))) and ok
		ok = _check("%d장(%s) 이름표가 (중간보스) 접미사 없이 실제 라벨" % [chapter, kind_id],
			enemy.get_node("Name").text == expected["label"]) and ok

		enemy.queue_free()
		await get_tree().process_frame

	print("RESULT ", "PASS" if ok else "FAIL")
	get_tree().quit()


func _check(label: String, cond: bool) -> bool:
	print(label, " ", "OK" if cond else "FAIL")
	return cond
