class_name PremiumManager
extends RefCounted
## Sklep premium i nagrody za reklamy (logika – bez interfejsu i bez wtyczek):
## przyznawanie zakupów (każda transakcja raz – po tokenie), podwójne żarokryształy przy pierwszym
## zakupie pakietu, Pakiet Popielnika, Przymierze Żaru (dzienne żarokryształy przez 30 dni),
## Mieszek Kupca (nagrody bez reklam, slot wypraw, offline), Złoty Karnet, limity reklam.
## Stan: s.premium = {tokens, owned, first, monthly_until, monthly_claim, history, ads}.

const AD_DAILY_LIMIT := 12
const FREE_CHEST_COOLDOWN := 4 * 3600.0
const FURY_SEC := 300.0
const PLACEMENTS := {
	"offline_double": {"name": "Podwój nagrodę offline"},
	"free_chest": {"name": "Darmowa skrzynia (co 4 h)"},
	"fury": {"name": "Zwój Furii: ×2 obrażenia i złoto na 5 min"},
	"tower_attempt": {"name": "Dodatkowa próba w Wieży (raz dziennie)"},
	"wheel_spin": {"name": "Dodatkowy obrót Koła Żaru (raz dziennie)"},
}

var gm: IdleGame
var _fury_was := false


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("premium"):
		gm.s["premium"] = {"tokens": [], "owned": {}, "first": {}, "monthly_until": 0.0, "monthly_claim": "", "history": [],
			"ads": {"day": "", "count": 0, "chest_at": 0.0, "fury_until": 0.0, "tower_day": ""}}
	return gm.s.premium


func catalog() -> Array:
	return gm.db.store.get("products", [])


func product(id: String) -> Dictionary:
	for p in catalog():
		if str(p.id) == id:
			return p
	return {}


func owns(kind: String) -> bool:
	return bool(_st().owned.get(kind, false))


func has_purse() -> bool:
	return owns("purse")


static func now() -> float:
	return Time.get_unix_time_from_system()


# --- Zakupy --------------------------------------------------------------------------

## Czy produkt można teraz kupić (jednorazowe tylko raz).
func can_buy(id: String) -> bool:
	var p := product(id)
	if p.is_empty():
		return false
	if not bool(p.consumable) and owns(str(p.kind)):
		return false
	if str(p.kind) == "season" and gm.season.premium():
		return false
	return true


func is_first(id: String) -> bool:
	return bool(gm.db.store.get("first_purchase_double", false)) and not bool(_st().first.get(id, false))


## Przyznaje zakup; zwraca łup [[id, ilość, rzadkość]]. Ten sam token nie jest przyznawany drugi raz.
func grant(id: String, token: String) -> Array:
	var st := _st()
	if token != "" and (st.tokens as Array).has(token):
		return []
	var p := product(id)
	if p.is_empty():
		return []
	var got: Array = []
	var kind := str(p.kind)
	if not bool(p.consumable) and owns(kind):
		# Przywrócenie już posiadanego – nic nowego.
		if token != "":
			st.tokens.append(token)
		return []
	match kind:
		"gems":
			var g := int(p.gems) * (2 if is_first(id) else 1) + int(p.get("bonus", 0))
			st.first[id] = true
			gm.add_gems(g)
			got.append(["gems", g, 0])
		"starter":
			gm.add_gems(int(p.gems))
			got.append(["gems", int(p.gems), 0])
			for it in p.get("items", []):
				gm.inventory.add(str(it[0]), int(it[1]))
				got.append([str(it[0]), int(it[1]), 4])
			var rn := gm.runes.random_rune(float(p.get("rune_power", 0.5)))
			gm.inventory.add(rn, 1)
			got.append([rn, 1, 4])
			st.owned["starter"] = true
		"monthly":
			gm.add_gems(int(p.gems))
			got.append(["gems", int(p.gems), 0])
			st.monthly_until = maxf(now(), float(st.monthly_until)) + float(p.days) * 86400.0
			st.monthly_claim = ""
		"purse":
			st.owned["purse"] = true
			gm.stats.mark_dirty()
		"season":
			gm.season.unlock_premium()
	if token != "":
		st.tokens.append(token)
		if st.tokens.size() > 400:
			st.tokens = st.tokens.slice(st.tokens.size() - 400)
	st.history.append({"id": id, "t": now()})
	gm.stats.mark_dirty()
	gm.save.save_game()
	gm.changed.emit("premium")
	return got


# --- Przymierze Żaru (karta miesięczna) ---------------------------------------------------

func monthly_active() -> bool:
	return float(_st().monthly_until) > now()


func monthly_days_left() -> int:
	return maxi(0, int(ceil((float(_st().monthly_until) - now()) / 86400.0)))


func monthly_ready() -> bool:
	return monthly_active() and str(_st().monthly_claim) != DailyManager.today()


func claim_monthly() -> int:
	if not monthly_ready():
		return 0
	var g := int(product("pk_monthly").get("daily_gems", 100))
	_st().monthly_claim = DailyManager.today()
	gm.add_gems(g)
	gm.changed.emit("premium")
	return g


## Premie stałe: {gold, offline, exped_slots}.
func bonuses() -> Dictionary:
	return {"gold": float(product("pk_monthly").get("gold_bonus", 0.1)) if monthly_active() else 0.0,
		"offline": 0.25 if has_purse() else 0.0, "exped_slots": 1 if has_purse() else 0}


# --- Reklamy z nagrodą ----------------------------------------------------------------

func _ads() -> Dictionary:
	var a: Dictionary = _st().ads
	if str(a.day) != DailyManager.today():
		a.day = DailyManager.today()
		a.count = 0
	return a


func ads_left() -> int:
	return AD_DAILY_LIMIT - int(_ads().count)


## Czy miejsce na nagrodę jest dostępne (limit, odnowienie).
func ad_available(place: String) -> bool:
	if ads_left() <= 0 and not has_purse():
		return false
	var a := _ads()
	match place:
		"free_chest":
			return now() >= float(a.chest_at)
		"tower_attempt":
			return str(a.tower_day) != DailyManager.today()
		"wheel_spin":
			return str(a.get("wheel_day", "")) != DailyManager.today()
		"fury":
			return now() >= float(a.fury_until)
	return true


func free_chest_wait() -> float:
	return maxf(0.0, float(_ads().chest_at) - now())


## Nagroda po obejrzeniu reklamy (albo od razu z Mieszkiem Kupca). Zwraca opis.
func ad_reward(place: String) -> String:
	if not ad_available(place):
		return ""
	var a := _ads()
	if not has_purse():
		a.count = int(a.count) + 1
	match place:
		"free_chest":
			a.chest_at = now() + FREE_CHEST_COOLDOWN
			var r := 2 if gm.progression.region_index(int(gm.s.max_stage)) < 3 else 3
			gm.inventory.add("chest_%d" % r, 1)
			gm.changed.emit("premium")
			return LootManager.CHEST_NAMES[r]
		"fury":
			a.fury_until = now() + FURY_SEC
			gm.stats.mark_dirty()
			gm.changed.emit("premium")
			return "Zwój Furii: ×2 obrażenia i złoto przez 5 minut!"
		"tower_attempt":
			a.tower_day = DailyManager.today()
			gm.s.tower.attempts = gm.tower.attempts() + 1
			gm.changed.emit("tower")
			return "+1 próba w Wieży Popiołu"
		"wheel_spin":
			a.wheel_day = DailyManager.today()
			gm.wheel.add_free_spin()
			return "+1 obrót Koła Żaru"
	gm.changed.emit("premium")
	return "ok"


func fury_active() -> bool:
	return now() < float(_ads().fury_until)


func fury_left() -> float:
	return maxf(0.0, float(_ads().fury_until) - now())


## Co klatkę gry: koniec Zwoju Furii przelicza statystyki.
func tick(_dt: float) -> void:
	var f := fury_active()
	if f != _fury_was:
		_fury_was = f
		gm.stats.mark_dirty()
