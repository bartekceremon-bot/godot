class_name RelicManager
extends RefCounted
## Relikwie Pięciu Królestw: 12 pradawnych przedmiotów w 4 zestawach po 3. Odłamki relikwii
## (lochy, arena, nagrody tygodnia) wymienia się w Relikwiarzu na losową relikwię – nową
## albo kolejny poziom posiadanej (maks. 10). Każda relikwia daje stałą premię, komplet
## zestawu – dodatkową premię zestawu (mocniejszą, gdy cały zestaw ma poziom 5+).
## Stan: s.relics = {shards, owned: {id: poziom}, pulls}.

const PULL_COST := 10
const MAX_LVL := 10
## id: [nazwa, zestaw, statystyka, wartość na poziom, opis]
const RELICS := {
	"crown": ["Korona Pięciu Królestw", "kings", "gold", 0.06, "złota"],
	"scepter": ["Berło Ostatniego Króla", "kings", "dmg", 0.05, "obrażeń"],
	"signet": ["Sygnet Władcy", "kings", "crit", 0.006, "szansy krytyka"],
	"fang": ["Kieł Żarogniewa", "dragon", "critdmg", 0.08, "obrażeń krytycznych"],
	"scale": ["Łuska Smoczej Tarczy", "dragon", "dmg", 0.05, "obrażeń"],
	"eye": ["Oko Smoka", "dragon", "spell", 0.06, "siły czarów"],
	"compass": ["Kompas Pielgrzyma", "pilgrim", "xp", 0.06, "doświadczenia"],
	"hourglass": ["Klepsydra Wieczności", "pilgrim", "speed", 0.02, "szybkości ataku"],
	"lantern": ["Latarnia Wędrowca", "pilgrim", "loot", 0.03, "szansy na łup"],
	"tear": ["Lodowa Łza", "frost", "merc", 0.06, "DPS najemników"],
	"horn": ["Róg Szronu", "frost", "dmg", 0.05, "obrażeń"],
	"heart": ["Serce Zimy", "frost", "gold", 0.05, "złota"],
}
## zestaw: [nazwa, statystyka, premia (komplet), premia (komplet 5+), opis]
const SETS := {
	"kings": ["Dziedzictwo Królów", "gold", 0.15, 0.4, "złota"],
	"dragon": ["Oręż Smokobójcy", "dmg", 0.15, 0.4, "obrażeń"],
	"pilgrim": ["Sakwy Pielgrzyma", "xp", 0.15, 0.4, "doświadczenia"],
	"frost": ["Skarby Szronu", "merc", 0.15, 0.4, "DPS najemników"],
}
const SET_ORDER := ["kings", "dragon", "pilgrim", "frost"]

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("relics"):
		gm.s["relics"] = {"shards": 0, "owned": {}, "pulls": 0}
	return gm.s.relics


func shards() -> int:
	return int(_st().shards)


func add_shards(n: int) -> void:
	_st().shards = shards() + n
	gm.changed.emit("relics")


func level(id: String) -> int:
	return int(_st().owned.get(id, 0))


func owned_count() -> int:
	return _st().owned.size()


static func relic_name(id: String) -> String:
	return str(RELICS[id][0])


static func describe(id: String, lvl: int) -> String:
	var r: Array = RELICS[id]
	var v := float(r[3]) * maxi(lvl, 1)
	return "+%s%% %s" % [_pct(v), r[4]]


static func _pct(v: float) -> String:
	var p := v * 100.0
	return str(roundi(p)) if absf(p - roundf(p)) < 0.05 else "%.1f" % p


## Poziom kompletu: 0 – niepełny, 1 – komplet, 2 – komplet z poziomami 5+.
func set_level(set_id: String) -> int:
	var lv := 99
	for id in RELICS:
		if str(RELICS[id][1]) == set_id:
			lv = mini(lv, level(id))
	if lv <= 0:
		return 0
	return 2 if lv >= 5 else 1


func can_pull() -> bool:
	return shards() >= PULL_COST and not _all_maxed()


func _all_maxed() -> bool:
	for id in RELICS:
		if level(id) < MAX_LVL:
			return false
	return true


## Losowa relikwia (bez tych na maksymalnym poziomie). Zwraca [id, nowy poziom].
func pull() -> Array:
	if not can_pull():
		return []
	var pool: Array = []
	for id in RELICS:
		if level(id) < MAX_LVL:
			# Brakujące relikwie trochę częściej – kolekcja rośnie szybciej na początku.
			pool.append(id)
			if level(id) == 0:
				pool.append(id)
	var id: String = pool[_rng.randi() % pool.size()]
	var st := _st()
	st.shards = shards() - PULL_COST
	st.owned[id] = level(id) + 1
	st.pulls = int(st.pulls) + 1
	gm.stats.mark_dirty()
	gm.changed.emit("relics")
	return [id, level(id)]


## Premie do PlayerStats (te same klucze co runy).
func totals() -> Dictionary:
	var t := {}
	for id in RELICS:
		var lv := level(id)
		if lv > 0:
			var r: Array = RELICS[id]
			t[str(r[2])] = float(t.get(str(r[2]), 0.0)) + float(r[3]) * lv
	for sid in SETS:
		var sl := set_level(sid)
		if sl > 0:
			var s: Array = SETS[sid]
			t[str(s[1])] = float(t.get(str(s[1]), 0.0)) + float(s[2] if sl == 1 else s[3])
	return t
