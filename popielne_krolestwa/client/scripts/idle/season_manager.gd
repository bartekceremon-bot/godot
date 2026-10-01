class_name SeasonManager
extends RefCounted
## Karnet Popiołu: sezony po 28 dni. Punkty karnetu za grę (wrogowie, bossowie, piętra Wieży,
## wyprawy, nagroda dnia, zlecenia, Boss tygodnia). 30 poziomów; ścieżka darmowa dla wszystkich
## i złota (Złoty Karnet z Google Play) – odblokowanie działa także wstecz na odebrane poziomy.
## Stan: s.season = {id, xp, premium, free: [poziomy], gold: [poziomy], kills}.

const DAYS := 28
const LEVELS := 30
const XP_PER_LEVEL := 120

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


static func season_id(t := -1.0) -> int:
	var at := Time.get_unix_time_from_system() if t < 0.0 else t
	return int(floor(at / 86400.0 / DAYS))


func days_left() -> int:
	var at := Time.get_unix_time_from_system()
	return int(ceil((float(season_id() + 1) * DAYS * 86400.0 - at) / 86400.0))


func _st() -> Dictionary:
	if not gm.s.has("season"):
		gm.s["season"] = {"id": -1, "xp": 0, "premium": false, "free": [], "gold": [], "kills": 0}
	var s: Dictionary = gm.s.season
	if int(s.id) != season_id():
		s.id = season_id()
		s.xp = 0
		s.premium = false
		s.free = []
		s.gold = []
		s.kills = 0
	return s


func premium() -> bool:
	return bool(_st().premium)


func unlock_premium() -> void:
	_st().premium = true
	gm.changed.emit("season")


func xp() -> int:
	return int(_st().xp)


func level() -> int:
	return mini(LEVELS, xp() / XP_PER_LEVEL)


func add_xp(n: int) -> void:
	var before := level()
	_st().xp = xp() + int(round(n * (1.2 if premium() else 1.0)))
	if level() > before:
		gm.notify("Karnet Popiołu: poziom %d!" % level(), Color(1.0, 0.8, 0.35))
		gm.changed.emit("season")


func on_kill() -> void:
	var s := _st()
	s.kills = int(s.kills) + 1
	if int(s.kills) % 20 == 0:
		add_xp(1)


## Nagroda poziomu (1..30) na ścieżce darmowej / złotej.
static func reward(lv: int, gold: bool) -> Dictionary:
	if gold:
		if lv == LEVELS:
			return {"skin": "ashprince", "gems": 200}
		if lv % 10 == 0:
			return {"egg": 1, "gems": 60}
		if lv % 5 == 0:
			return {"chest": 4}
		if lv % 3 == 0:
			return {"rune": 0.6}
		return {"gems": 40}
	if lv % 10 == 0:
		return {"egg": 1}
	if lv % 5 == 0:
		return {"chest": 3}
	if lv % 2 == 0:
		return {"gems": 10}
	return {"chest": 1}


static func reward_text(r: Dictionary) -> String:
	var parts: Array = []
	if r.has("gems"):
		parts.append("%d żarokr." % int(r.gems))
	if r.has("chest"):
		parts.append(LootManager.CHEST_NAMES[int(r.chest)])
	if r.has("rune"):
		parts.append("runa")
	if r.has("egg"):
		parts.append("jajo chowańca")
	if r.has("skin"):
		parts.append("strój „Popielny Książę”")
	return ", ".join(PackedStringArray(parts))


func claimable(lv: int, gold: bool) -> bool:
	var s := _st()
	if lv > level():
		return false
	if gold and not premium():
		return false
	return not (s.gold if gold else s.free).has(lv)


func claimed(lv: int, gold: bool) -> bool:
	return (_st().gold if gold else _st().free).has(lv)


func ready_count() -> int:
	var n := 0
	for lv in range(1, level() + 1):
		if claimable(lv, false):
			n += 1
		if claimable(lv, true):
			n += 1
	return n


func claim(lv: int, gold: bool) -> Array:
	if not claimable(lv, gold):
		return []
	var r := reward(lv, gold)
	var got: Array = []
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems), 0])
	if r.has("chest"):
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1, int(r.chest)])
	if r.has("rune"):
		var rn := gm.runes.random_rune(float(r.rune))
		gm.inventory.add(rn, 1)
		got.append([rn, 1, 4])
	if r.has("egg"):
		gm.inventory.add("pet_egg", int(r.egg))
		got.append(["pet_egg", int(r.egg), 4])
	if r.has("skin"):
		gm.skins.give(str(r.skin))
	(_st().gold if gold else _st().free).append(lv)
	gm.changed.emit("season")
	return got


func claim_all() -> Array:
	var got: Array = []
	for lv in range(1, level() + 1):
		got.append_array(claim(lv, false))
		got.append_array(claim(lv, true))
	return got
