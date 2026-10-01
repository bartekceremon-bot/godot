class_name PetManager
extends RefCounted
## Chowańce: zwierzaki wykluwane z jaj (bossowie, Wieża, wyprawy, Boss tygodnia). Każdy daje
## premię rosnącą z poziomem (maks. 10 × gwiazdki); kolejne jajo tego samego gatunku = gwiazdka.
## Aktywny chowaniec chodzi za bohaterem w scenie walki; drugi slot od 25. piętra Wieży.
## Stan: s.pets = {owned: {id: {lvl, stars}}, active: [id...]}; jaja w s.inv jako "pet_egg".

const PETS := [
	{"id": "fox", "name": "Lisek Szronek", "look": "snow_fox", "rarity": 1, "stat": "gold", "per": 0.03, "text": "złota"},
	{"id": "wolfling", "name": "Wilczek Kieł", "look": "wolf", "rarity": 1, "stat": "dmg", "per": 0.02, "text": "obrażeń"},
	{"id": "toadling", "name": "Ropuszek", "look": "toad", "rarity": 1, "stat": "xp", "per": 0.03, "text": "doświadczenia"},
	{"id": "scarab", "name": "Skarabeusz Złotek", "look": "scarab", "rarity": 2, "stat": "loot", "per": 0.015, "text": "szansy na łup"},
	{"id": "hound", "name": "Ogar Popiołu", "look": "hound", "rarity": 2, "stat": "crit", "per": 0.003, "text": "szansy krytyka"},
	{"id": "basilisk", "name": "Bazyliszek Łuska", "look": "basilisk", "rarity": 3, "stat": "spell", "per": 0.04, "text": "siły czarów"},
	{"id": "bear", "name": "Niedźwiadek Burek", "look": "bear", "rarity": 3, "stat": "merc", "per": 0.04, "text": "DPS najemników"},
	{"id": "drakeling", "name": "Smoczek Żarek", "look": "mount_drake", "rarity": 4, "stat": "dmg", "per": 0.06, "text": "obrażeń"},
]
const RARITY_W := [0, 46, 30, 17, 7]
const RARITY_NAMES := ["", "Pospolity", "Rzadki", "Epicki", "Legendarny"]
const MAX_STARS := 5

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("pets"):
		gm.s["pets"] = {"owned": {}, "active": []}
	return gm.s.pets


static func def(id: String) -> Dictionary:
	for p in PETS:
		if str(p.id) == id:
			return p
	return {}


func owned() -> Dictionary:
	return _st().owned


func level(id: String) -> int:
	return int(owned().get(id, {}).get("lvl", 0))


func stars(id: String) -> int:
	return int(owned().get(id, {}).get("stars", 0))


func max_level(id: String) -> int:
	return 10 * stars(id)


func value(id: String, lvl := -1) -> float:
	var d := def(id)
	var l := level(id) if lvl < 0 else lvl
	return float(d.per) * l * (1.0 + 0.25 * (stars(id) - 1))


func slots() -> int:
	return 1 + (1 if gm.tower.best() >= 25 else 0)


func active() -> Array:
	return _st().active


## Wyklucie jaja: nowy gatunek albo gwiazdka (przy 5 gwiazdkach – 60 żarokryształów).
func hatch() -> Dictionary:
	if not gm.inventory.remove("pet_egg", 1):
		return {}
	var total := 0.0
	for p in PETS:
		total += float(RARITY_W[int(p.rarity)]) / _count_of_rarity(int(p.rarity))
	var r := _rng.randf() * total
	var pick: Dictionary = PETS[0]
	for p in PETS:
		r -= float(RARITY_W[int(p.rarity)]) / _count_of_rarity(int(p.rarity))
		if r <= 0.0:
			pick = p
			break
	var id := str(pick.id)
	var res := {"id": id, "new": false, "star": false, "gems": 0}
	if not owned().has(id):
		owned()[id] = {"lvl": 1, "stars": 1}
		res.new = true
		if active().size() < slots():
			active().append(id)
	elif stars(id) < MAX_STARS:
		owned()[id].stars = stars(id) + 1
		res.star = true
	else:
		gm.add_gems(60)
		res.gems = 60
	gm.audio.play("rare")
	gm.stats.mark_dirty()
	gm.changed.emit("pets")
	return res


func _count_of_rarity(r: int) -> float:
	var n := 0
	for p in PETS:
		if int(p.rarity) == r:
			n += 1
	return float(maxi(n, 1))


func level_cost(id: String) -> float:
	return ProgressionManager.gold_for(int(gm.s.max_stage)) * 15.0 * pow(1.22, level(id)) * (1.0 + 0.5 * (int(def(id).rarity) - 1))


func level_up(id: String) -> bool:
	if level(id) <= 0 or level(id) >= max_level(id) or not gm.spend_gold(level_cost(id)):
		return false
	owned()[id].lvl = level(id) + 1
	gm.stats.mark_dirty()
	gm.changed.emit("pets")
	return true


func set_active(id: String) -> bool:
	if not owned().has(id):
		return false
	var a := active()
	if a.has(id):
		a.erase(id)
	else:
		if a.size() >= slots():
			a.remove_at(0)
		a.append(id)
	gm.stats.mark_dirty()
	gm.changed.emit("pets")
	return true


func totals() -> Dictionary:
	var t := {}
	for id in active():
		var d := def(str(id))
		if not d.is_empty():
			t[str(d.stat)] = float(t.get(str(d.stat), 0.0)) + value(str(id))
	return t
