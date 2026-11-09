extends Node

const DEFAULT_SCORES: Array = []

var scores: Array = []


func _ready() -> void:
	load_scores()


func _get_scores_path() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://data/high_scores.json")
	return "user://leaderboard_scores.json"


func _parse_scores_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else null


func load_scores() -> Array:
	var path = _get_scores_path()
	var parsed = _parse_scores_file(path)
	if parsed == null and not OS.has_feature("editor"):
		parsed = _parse_scores_file("res://data/high_scores.json")
	if parsed is Array:
		scores = parsed.duplicate(true)
		scores.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
		scores = scores.slice(0, 10)
		if not FileAccess.file_exists(path):
			save_scores()
		return scores

	scores = DEFAULT_SCORES.duplicate(true)
	save_scores()
	return scores


func save_scores() -> void:
	var json_str = JSON.stringify(scores, "  ")
	var path = _get_scores_path()
	if not path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(json_str)
		f.close()


func clear_scores() -> void:
	scores.clear()
	save_scores()


func add_score(pilot_name: String, score_val: int) -> void:
	var clean_name = pilot_name.strip_edges().to_upper().substr(0, 10)
	if clean_name.is_empty():
		clean_name = "PILOT"
	var dt = Time.get_date_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	scores.append({
		"name": clean_name,
		"score": int(score_val),
		"date": date_str
	})
	scores.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	scores = scores.slice(0, 10)
	save_scores()


func get_top_score() -> int:
	if scores.is_empty():
		return 0
	return int(scores[0].get("score", 0))
