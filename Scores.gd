extends Node
## 점수 저장/불러오기 오토로드 (user://ranking.json)

const SAVE_PATH   := "user://ranking.json"
const MAX_ENTRIES := 5

func save_score(score: int) -> void:
	var list := load_scores()
	var date := Time.get_date_string_from_system()
	list.append({"score": score, "date": date})
	list.sort_custom(func(a, b): return a["score"] > b["score"])
	while list.size() > MAX_ENTRIES:
		list.pop_back()
	_write(list)

func load_scores() -> Array:
	if not FileAccess.file_exists(SAVE_PATH):
		return []
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return []
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []

func _write(data: Array) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
