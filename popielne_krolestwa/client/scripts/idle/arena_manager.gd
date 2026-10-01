class_name ArenaManager
extends RefCounted
## Arena Popiołu: pojedynki z championami innych Popielników (rywale generowani z rankingu
## gracza – gra działa bez serwera). Ranking ELO, ligi od Brązu do Legendy, 5 biletów
## dziennie, odznaki chwały za walki do wydania w sklepie areny, cotygodniowa nagroda ligowa.
## Stan: s.arena = {rating, best, week_best, week, day, tickets, coins, wins, losses, rivals, claimed_week, buys}.

const DAILY_TICKETS := 5
const EXTRA_COST := 25
const TIME := 30.0
const K := 32.0
const LEAGUES := [
	["Brąz", 0, Color(0.8, 0.55, 0.35)],
	["Srebro", 1200, Color(0.8, 0.84, 0.9)],
	["Złoto", 1450, Color(1.0, 0.82, 0.3)],
	["Platyna", 1700, Color(0.55, 0.95, 0.9)],
	["Diament", 2000, Color(0.6, 0.75, 1.0)],
	["Legenda", 2400, Color(1.0, 0.45, 0.3)],
]
## Nagroda tygodnia za najwyższą ligę: [żarokryształy, skrzynia, odznaki, odłamki].
const WEEKLY := [[20, 1, 30, 1], [40, 2, 50, 2], [70, 3, 80, 3], [110, 3, 120, 5], [160, 4, 180, 7], [250, 5, 260, 10]]
## Sklep areny: [id, nazwa, koszt, limit dzienny (0 – bez)].
const SHOP := [
	["chest_3", "Rzadka skrzynia", 60, 0],
	["chest_4", "Epicka skrzynia", 160, 0],
	["rune", "Losowa runa", 90, 0],
	["pet_egg", "Jajo chowańca", 220, 1],
	["shards", "5 odłamków relikwii", 120, 2],
	["gems", "40 żarokryształów", 200, 1],
	["key", "Klucz do lochu (losowy)", 70, 2],
	["seal", "Pieczęć Przebudzenia", 150, 1],
]
const TAG_A := ["Popielny", "Krwawy", "Szary", "Złoty", "Mroczny", "Cichy", "Żelazny", "Szronowy", "Dziki", "Stary", "Ognisty", "Kruczy"]
const TAG_B := ["Wilk", "Kruk", "Rycerz", "Łowca", "Smok", "Mag", "Lis", "Topór", "Cień", "Ogar", "Kieł", "Pielgrzym"]
const LOOKS := ["bandit", "bandit_archer", "orc", "orc_shaman", "ash_knight", "skeleton", "lizard", "mummy"]

var gm: IdleGame
var active := false
var rival: Dictionary = {}
var last_fight: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func _st() -> Dictionary:
	if not gm.s.has("arena"):
		gm.s["arena"] = {"rating": 1000, "best": 1000, "week_best": 1000, "week": RaidManager.week_id(), "day": "", "tickets": DAILY_TICKETS,
			"coins": 0, "wins": 0, "losses": 0, "rivals": [], "claimed_week": -1, "buys": {}}
	var a: Dictionary = gm.s.arena
	if str(a.day) != DailyManager.today():
		a.day = DailyManager.today()
		a.tickets = DAILY_TICKETS + 2 * int(gm.events.bonus("arena"))
		a.buys = {}
	if int(a.week) != RaidManager.week_id():
		a.week = RaidManager.week_id()
		# Miękki reset na nowy tydzień: ranking zbliża się do 1000.
		a.rating = 1000 + int((int(a.rating) - 1000) * 0.75)
		a.week_best = int(a.rating)
		a.rivals = []
	if a.rivals.is_empty():
		_roll_rivals(a)
	return a


func unlocked() -> bool:
	return int(gm.achievements.value("best_stage")) >= 25


func rating() -> int:
	return int(_st().rating)


func tickets() -> int:
	return int(_st().tickets)


func coins() -> int:
	return int(_st().coins)


func rivals() -> Array:
	return _st().rivals


static func league(r: int) -> int:
	var l := 0
	for i in LEAGUES.size():
		if r >= int(LEAGUES[i][1]):
			l = i
	return l


static func league_name(r: int) -> String:
	return str(LEAGUES[league(r)][0])


## Szansa wygranej wg ELO (do podpowiedzi przy rywalach).
static func expected(a: int, b: int) -> float:
	return 1.0 / (1.0 + pow(10.0, (b - a) / 400.0))


func _roll_rivals(a: Dictionary) -> void:
	var r := int(a.rating)
	var list: Array = []
	for off in [-120, 0, 150]:
		var rr := maxi(800, r + off + _rng.randi_range(-40, 40))
		var name := "%s%s%s" % [TAG_A[_rng.randi() % TAG_A.size()], TAG_B[_rng.randi() % TAG_B.size()], ("_%d" % _rng.randi_range(2, 99)) if _rng.randf() < 0.5 else ""]
		list.append({"name": name, "rating": rr, "look": LOOKS[_rng.randi() % LOOKS.size()], "level": maxi(1, int(gm.s.level) + _rng.randi_range(-3, 4) + int(off / 60))})
	a.rivals = list


## Odśwież rywali (raz za darmo po każdej walce; ręcznie za 5 żarokryształów).
func reroll() -> bool:
	if active or not gm.spend_gems(5):
		return false
	_roll_rivals(_st())
	gm.changed.emit("arena")
	return true


## Szacowana siła bohatera: obrażenia w 30 s (DPS + ok. 5 kliknięć na sekundę).
func power() -> float:
	var st := gm.stats
	return (st.dps + st.click * 5.0 * (1.0 + st.crit_chance * (st.crit_mult - 1.0))) * TIME


## Zdrowie championa rywala: im wyższy ranking względem gracza, tym twardszy.
func rival_hp(rv: Dictionary) -> float:
	var f := clampf(0.55 * pow(2.0, (int(rv.rating) - rating()) / 300.0), 0.3, 2.2)
	return maxf(50.0, power() * f)


func can_fight() -> bool:
	return gm.running and gm.challenge() == null and unlocked()


func fight(i: int, use_gems := false) -> bool:
	var st := _st()
	if not can_fight() or i < 0 or i >= st.rivals.size():
		return false
	if tickets() > 0:
		st.tickets = tickets() - 1
	elif not (use_gems and gm.spend_gems(EXTRA_COST)):
		return false
	rival = st.rivals[i]
	active = true
	gm.combat.heal_full()
	gm.enemy.spawn()
	gm.changed.emit("arena")
	return true


func make_enemy() -> Dictionary:
	var hp := rival_hp(rival)
	var look := str(rival.look)
	# Ciosy championa jak elity bieżącego etapu (silniejsi rywale biją trochę mocniej).
	var stage := maxi(1, int(gm.s.max_stage) - 5 + int((int(rival.rating) - rating()) / 100))
	return {"monster": look, "name": "%s (%s)" % [rival.name, league_name(int(rival.rating))], "look": look, "max_hp": hp, "hp": hp, "kind": 2,
		"stage": stage, "time_left": TIME, "time_max": TIME, "frozen": 0.0, "vuln": 0.0, "vuln_t": 0.0, "undead": false, "challenge": "arena"}


func on_kill(_e: Dictionary) -> void:
	_end(true, "zwycięstwo!")


func on_fail(reason: String) -> void:
	_end(false, reason)


func _end(win: bool, reason: String) -> void:
	if not active:
		return
	active = false
	var st := _st()
	var me := rating()
	var ex := expected(me, int(rival.rating))
	var delta := roundi(K * ((1.0 if win else 0.0) - ex))
	if win:
		delta = maxi(delta, 6)
	st.rating = maxi(0, me + delta)
	st.best = maxi(int(st.best), int(st.rating))
	st.week_best = maxi(int(st.week_best), int(st.rating))
	var c := ((12 + int(int(rival.rating) / 250)) if win else 4) * (1 + int(gm.events.bonus("arena")))
	st.coins = coins() + c
	var shard := false
	if win:
		st.wins = int(st.wins) + 1
		if _rng.randf() < 0.25:
			gm.relics.add_shards(1)
			shard = true
	else:
		st.losses = int(st.losses) + 1
	gm.season.add_xp(12 if win else 4)
	gm.quests.on_event("arena", 1)
	last_fight = {"win": win, "delta": delta, "coins": c, "shard": shard, "rival": rival.duplicate(), "rating": int(st.rating), "reason": reason}
	_roll_rivals(st)
	gm.combat.heal_full()
	gm.save.save_game()
	gm.audio.play("levelup" if win else "fail")
	gm.changed.emit("arena")
	gm.toast.emit("Arena: %s  %+d (ranking %d)" % ["zwycięstwo" if win else "porażka", delta, int(st.rating)], Color(0.6, 1.0, 0.5) if win else Color(1.0, 0.55, 0.4))


func leave() -> void:
	if active:
		on_fail("poddano walkę")
		gm.enemy.spawn()


func hud_text() -> String:
	return "ARENA  •  %s  •  ranking %d" % [league_name(rating()).to_upper(), rating()]


# --- Nagroda tygodnia i sklep ------------------------------------------------------

func weekly_ready() -> bool:
	var st := _st()
	return int(st.claimed_week) != int(st.week) and (int(st.wins) + int(st.losses)) > 0


func weekly_reward() -> Array:
	return WEEKLY[league(int(_st().week_best))]


func claim_weekly() -> Array:
	if not weekly_ready():
		return []
	var st := _st()
	var w: Array = weekly_reward()
	st.claimed_week = int(st.week)
	gm.add_gems(int(w[0]))
	gm.inventory.add("chest_%d" % int(w[1]), 1)
	st.coins = coins() + int(w[2])
	gm.relics.add_shards(int(w[3]))
	gm.changed.emit("arena")
	return [["gems", int(w[0])], ["chest_%d" % int(w[1]), 1], ["coins", int(w[2])], ["shards", int(w[3])]]


func bought_today(id: String) -> int:
	return int(_st().buys.get(id, 0))


func can_buy(i: int) -> bool:
	var it: Array = SHOP[i]
	return coins() >= int(it[2]) and (int(it[3]) == 0 or bought_today(str(it[0])) < int(it[3]))


func buy(i: int) -> String:
	if i < 0 or i >= SHOP.size() or not can_buy(i):
		return ""
	var it: Array = SHOP[i]
	var st := _st()
	st.coins = coins() - int(it[2])
	st.buys[str(it[0])] = bought_today(str(it[0])) + 1
	var id := str(it[0])
	match id:
		"rune":
			var rn := gm.runes.random_rune(0.6)
			gm.inventory.add(rn, 1)
			id = rn
		"shards":
			gm.relics.add_shards(5)
		"gems":
			gm.add_gems(40)
		"seal":
			gm.mercs.add_seals(1)
		"key":
			var d := gm.dungeon._st()
			var k: String = DungeonManager.ORDER[_rng.randi() % 3]
			d.keys[k] = int(d.keys.get(k, 0)) + 1
		_:
			gm.inventory.add(id, 1)
	gm.changed.emit("arena")
	return id
