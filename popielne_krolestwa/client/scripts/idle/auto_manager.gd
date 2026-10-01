class_name AutoManager
extends RefCounted
## Kwatermistrz – automatyzacja (odblokowywana postępem):
## • auto-najemnicy (po 1. odrodzeniu): co 3 s kupuje najlepszy stosunek DPS/koszt
##   (i trening ciosu), zostawiając wybraną rezerwę złota;
## • auto-ekwipunek (od etapu 20): zakłada najlepsze przedmioty i sprzedaje słabe (Zwykłe/Niezwykłe);
## • auto-odrodzenie (po 3. odrodzeniu): gdy postęp stoi od 3 min, a odrodzenie da co
##   najmniej wybraną ilość Popiołu Dusz.
## Stan: s.auto = {mercs, gear, rebirth, reserve, min_ash}.

const MERCS_REBIRTHS := 1
const GEAR_STAGE := 20
const REBIRTH_REBIRTHS := 3
const STUCK_SEC := 180.0
const RESERVES := [0.0, 0.25, 0.5]
const MIN_ASH := [1, 10, 50, 200, 1000]

var gm: IdleGame
var _t := 0.0
var _gear_t := 0.0
var _best_stage := 0
var _stuck := 0.0
## Ostatnie auto-odrodzenie (komunikat dla UI).
var last_rebirth_ash := 0


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("auto"):
		gm.s["auto"] = {"mercs": false, "gear": false, "rebirth": false, "reserve": 0, "min_ash": 1}
	return gm.s.auto


func rebirths() -> int:
	return int(gm.s.rebirths) + gm.phoenix.count()


func mercs_unlocked() -> bool:
	return rebirths() >= MERCS_REBIRTHS


func gear_unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= GEAR_STAGE


func rebirth_unlocked() -> bool:
	return rebirths() >= REBIRTH_REBIRTHS


func enabled(k: String) -> bool:
	return bool(_st().get(k, false))


func set_enabled(k: String, on: bool) -> void:
	_st()[k] = on
	gm.changed.emit("auto")


func reserve() -> float:
	return float(RESERVES[clampi(int(_st().reserve), 0, RESERVES.size() - 1)])


func min_ash() -> int:
	return int(MIN_ASH[clampi(int(_st().min_ash), 0, MIN_ASH.size() - 1)])


func cycle(k: String, n: int) -> void:
	var st := _st()
	st[k] = (int(st[k]) + 1) % n
	gm.changed.emit("auto")


func any_unlocked() -> bool:
	return mercs_unlocked() or gear_unlocked()


func tick(dt: float) -> void:
	if gm.challenge() != null:
		return
	_t += dt
	_gear_t += dt
	if _t >= 3.0:
		_t = 0.0
		if enabled("mercs") and mercs_unlocked():
			buy_mercs()
		if enabled("rebirth") and rebirth_unlocked():
			_check_rebirth(3.0)
	if _gear_t >= 10.0:
		_gear_t = 0.0
		if enabled("gear") and gear_unlocked():
			do_gear()


## Chciwy zakup: najlepszy przyrost DPS na złoto; trening, gdy cios odstaje. Zwraca liczbę zakupów.
func buy_mercs() -> int:
	var s := gm.s
	var keep := float(s.gold) * reserve()
	var n := 0
	for guard in 30:
		var budget := float(s.gold) - keep
		var best_id := ""
		var best_ratio := 0.0
		var best_cost := 0.0
		for d in gm.mercs.visible_list():
			var id := str(d.id)
			var c := gm.mercs.cost(id, 1)
			if c <= 0.0:
				continue
			var gain := gm.mercs.dps(id, gm.mercs.level(id) + 1) - gm.mercs.dps(id)
			var ratio := gain / c
			if ratio > best_ratio:
				best_ratio = ratio
				best_id = id
				best_cost = c
		var tc := gm.mercs.train_cost(1)
		if tc <= budget and (gm.stats.dps < gm.stats.click * 2.0 or tc < best_cost * 0.2):
			if not gm.mercs.buy_train(1):
				break
			n += 1
			continue
		if best_id != "" and best_cost <= budget and gm.mercs.buy(best_id, 1):
			n += 1
		else:
			break
	return n


func do_gear() -> void:
	gm.equipment.equip_best()
	gm.shop.sell_junk(2)


func _check_rebirth(dt: float) -> void:
	var ms := int(gm.s.max_stage)
	if ms > _best_stage:
		_best_stage = ms
		_stuck = 0.0
		return
	_stuck += dt
	if _stuck >= STUCK_SEC and gm.prestige.can_rebirth() and gm.prestige.ash_gain() >= min_ash():
		var ash := gm.prestige.ash_gain()
		if gm.prestige.rebirth():
			last_rebirth_ash = ash
			_best_stage = 0
			_stuck = 0.0
			gm.toast.emit("Kwatermistrz: automatyczne odrodzenie (+%d Popiołu Dusz)" % ash, Color(1.0, 0.75, 0.4))
