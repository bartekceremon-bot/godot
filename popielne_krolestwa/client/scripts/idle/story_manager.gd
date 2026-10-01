class_name StoryManager
extends RefCounted
## Fabuła: rozdział na krainę (data/idle/story.json). Wstęp przy pierwszym wejściu do krainy,
## zakończenie po pierwszym pokonaniu jej bossa, epilog przy każdym nowym Kręgu Popiołu.
## Sceny czekają w kolejce, aż UI będzie wolne. Stan: s.story = {seen: [id], pending: [id]}.

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("story"):
		gm.s["story"] = {"seen": [], "pending": []}
	return gm.s.story


func enabled() -> bool:
	return not gm.story_autotest and bool(gm.s.get("settings", {}).get("story", true))


func chapter(region_id: String) -> Dictionary:
	for c in gm.db.story.chapters:
		if str(c.region) == region_id:
			return c
	return {}


## Scena: "intro:<kraina>", "outro:<kraina>", "circle:<n>".
func lines(scene: String) -> Array:
	var p := scene.split(":")
	if p[0] == "circle":
		return gm.db.story.circle
	var c := chapter(p[1])
	return c.get(p[0], [])


func title(scene: String) -> String:
	var p := scene.split(":")
	if p[0] == "circle":
		return "Krąg Popiołu %d" % (int(p[1]) + 1)
	return str(chapter(p[1]).get("title", ""))


func queue(scene: String) -> void:
	var st := _st()
	if st.seen.has(scene) or st.pending.has(scene) or lines(scene).is_empty():
		return
	st.pending.append(scene)


func has_pending() -> bool:
	return enabled() and not _st().pending.is_empty()


func pop() -> String:
	var st := _st()
	if st.pending.is_empty():
		return ""
	var scene: String = st.pending.pop_front()
	st.seen.append(scene)
	return scene


func seen() -> Array:
	return _st().seen


## Nowy najdalszy etap: wejście do krainy (albo nowy Krąg).
func on_new_stage(stage: int) -> void:
	var per := gm.db.stages_per_region
	if (stage - 1) % per != 0:
		return
	var c := gm.progression.circle(stage)
	if c == 0:
		queue("intro:" + str(gm.progression.region(stage).id))
	elif gm.progression.region_index(stage) == 0:
		queue("circle:%d" % c)


func on_region_boss(stage: int) -> void:
	if gm.progression.circle(stage) == 0:
		queue("outro:" + str(gm.progression.region(stage).id))
