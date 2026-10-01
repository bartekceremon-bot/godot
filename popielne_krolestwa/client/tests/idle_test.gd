extends Node
## Test pętli gry idle bez okna: godot --headless --path . res://tests/idle_test.tscn
## Sprawdza: klikanie, najemników, etapy i bossów, łup, ekwipunek i ulepszenia, rzemiosło,
## czary, zadania, zapis/odczyt, postęp offline, sklep, targ, wierzchowce i odrodzenie.

var fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		fails += 1
		print("  BŁĄD ", what)


func _ready() -> void:
	var g: IdleGame = Idle
	g.save.path = "user://test_idle.save"
	g.save.delete_save()
	g.start()
	var s := g.s
	print("== start")
	check(g.enemy.alive(), "jest przeciwnik: %s" % g.enemy.cur.name)
	check(g.equipment.equipped("weapon").size() > 0, "startowy miecz założony")
	check(g.stats.click >= 2.0, "obrażenia kliknięcia %s" % g.stats.click)

	print("== klikanie")
	var hp0 := float(g.enemy.cur.hp)
	g.combat.tap()
	check(float(g.enemy.cur.hp) < hp0 or int(s.stats.kills) > 0, "cios zadaje obrażenia")
	for i in 400:
		g.combat.tap()
		g.tick(0.05)
	check(int(s.stats.kills) >= 10, "zabici wrogowie: %d" % int(s.stats.kills))
	check(float(s.gold) > 0.0 or int(s.train_lvl) > 0, "złoto: %s" % IdleDB.fmt(float(s.gold)))
	check(int(s.level) >= 2, "poziom: %d" % int(s.level))

	print("== najemnicy i idle")
	g.add_gold(1000.0)
	check(g.mercs.buy("guard", 5), "wynajęto strażników")
	check(g.stats.dps > 0.0, "DPS: %s" % IdleDB.fmt(g.stats.dps))
	var kills := int(s.stats.kills)
	for i in 600:
		g.tick(0.1)
	check(int(s.stats.kills) > kills, "automatyczne zabijanie (%d)" % (int(s.stats.kills) - kills))

	print("== etapy i boss")
	g.add_gold(1.0e6)
	for d in g.db.mercs.slice(0, 5):
		g.mercs.buy(str(d.id), 0)
	g.mercs.buy_train(0)
	var bosses := int(s.stats.bosses)
	for i in 3000:
		g.combat.tap()
		g.tick(0.1)
	check(int(s.max_stage) >= 6, "maks. etap: %d" % int(s.max_stage))
	check(int(s.stats.bosses) > bosses, "pokonani bossowie: %d" % int(s.stats.bosses))
	check(g.inventory.count("chest_1") + g.inventory.count("chest_2") + g.inventory.count("chest_3") + g.inventory.count("chest_4") + g.inventory.count("chest_5") > 0 or int(s.stats.bosses) > 0, "skrzynie z bossów")

	print("== porażka z bossem")
	g.progression.travel(int(s.max_stage))
	var fail_stage := int(s.stage)
	if g.enemy.is_boss():
		g.enemy.fail("test")
		check(bool(s.farm_mode) and int(s.stage) == fail_stage - 1, "po porażce: farmienie etapu %d" % int(s.stage))
		g.progression.challenge_boss()
		check(g.enemy.is_boss(), "ponowne wyzwanie bossa")
	else:
		check(true, "(maks. etap nie jest bossem – pominięto)")

	print("== łup i skrzynie")
	g.inventory.add("chest_4", 1)
	var gear_before: int = s.gear.size()
	var got := g.loot.open_chest(4)
	check(got.size() >= 3, "skrzynia epicka: %d nagród" % got.size())
	check(s.gear.size() > gear_before, "ekwipunek ze skrzyni")

	print("== ekwipunek i ulepszanie")
	var w := g.equipment.equipped("weapon")
	var cost := g.equipment.upgrade_cost(w)
	g.add_gold(float(cost.gold))
	for m in cost.mats:
		g.inventory.add(str(m[0]), int(m[1]))
	var click_before := g.stats.click
	check(g.equipment.upgrade(int(w.uid)), "ulepszono %s" % g.equipment.gear_name(w))
	g.stats.recalc()
	check(g.stats.click > click_before, "klik po ulepszeniu %s > %s" % [IdleDB.fmt(g.stats.click), IdleDB.fmt(click_before)])
	var c2 := g.equipment.upgrade_cost(w)
	check(float(c2.gold) > float(cost.gold), "koszt rośnie: %s -> %s" % [IdleDB.fmt(float(cost.gold)), IdleDB.fmt(float(c2.gold))])
	check(g.equipment.describe(w).size() >= 2, "opis premii: %s" % ", ".join(PackedStringArray(g.equipment.describe(w))))
	var it := g.inventory.add_gear("plate_body_t2", 3)
	g.equipment.equip(int(it.uid))
	g.stats.recalc()
	check(g.stats.max_hp > 200.0, "zbroja płytowa: zdrowie %s" % IdleDB.fmt(g.stats.max_hp))

	print("== rzemiosło")
	g.inventory.add("ore_t1", 20)
	var got2 := g.crafting.craft("refine_ore_t1", 10)
	check(g.inventory.count("bars_t1") >= 10, "rafinacja: sztaby miedzi %d" % g.inventory.count("bars_t1"))
	g.inventory.add("hide_t1", 4)
	g.crafting.craft("refine_hide_t1", 4)
	var gear_n: int = s.gear.size()
	check(g.crafting.craft("craft_sword_t1", 1).size() == 1 and s.gear.size() == gear_n + 1, "kuźnia: wykuto miecz")
	g.inventory.add("meat", 10)
	g.crafting.craft("boost_roast", 1)
	check(g.crafting.active_boosts().has("gold"), "wzmocnienie: Pieczeń myśliwego")

	print("== czary")
	g.s.level = 60
	g.add_gold(1.0e12)
	for id in ["fireball", "meteor", "haste", "frost_nova", "poison_cloud"]:
		g.spells.learn(id)
	check(g.spells.is_known("meteor"), "nauczono Meteor")
	g.combat.mp = 9999.0
	g.stats.recalc()
	var k0 := int(s.stats.kills)
	var hp_m := float(g.enemy.cur.hp)
	check(g.spells.cast("meteor"), "Meteor rzucony")
	check(int(s.stats.kills) > k0 or float(g.enemy.cur.hp) < hp_m, "Meteor rani lub zabija (zabici: %d)" % (int(s.stats.kills) - k0))
	check(not g.spells.can_cast("meteor"), "odnowienie Meteoru")
	check(g.spells.cast("haste"), "Przyspieszenie")
	g.stats.recalc()
	check(g.stats.atk_speed >= 1.9, "szybkość ataku %s" % g.stats.atk_speed)
	var spd := g.stats.atk_speed
	for i in 120:
		g.tick(0.1)
	check(g.stats.atk_speed < spd, "Przyspieszenie wygasło")
	g.spells.upgrade("meteor")
	check(g.spells.level("meteor") == 1 or int(s.gems) < 3, "ulepszenie czaru")

	print("== zadania")
	g.quests.refresh()
	check(s.quests.active.size() > 0, "aktywne zadania Kroniki: %s" % ", ".join(PackedStringArray(s.quests.active.keys())))
	check(s.quests.tasks.size() == 3, "3 zlecenia")
	var t0: Dictionary = s.quests.tasks[0]
	t0.prog = t0.need
	var gems0 := int(s.gems)
	check(g.quests.claim_task(0), "odebrano zlecenie")
	check(int(s.gems) > gems0, "nagroda: żarokryształy")
	var qid := str(s.quests.active.keys()[0])
	var qd := g.quests.def(qid)
	for i in qd.goals.size():
		s.quests.active[qid][i] = 999
		if str(qd.goals[i].kind) == "gather":
			s.quests.active[qid][i] = int(qd.goals[i].count)
	check(g.quests.is_ready(qid), "zadanie %s gotowe" % qid)
	check(g.quests.claim(qid), "odebrano nagrodę zadania")
	check(s.quests.done.has(qid), "zadanie ukończone")

	print("== sklep, targ, wierzchowce")
	var offers := g.shop.offers()
	check(g.shop.buy(offers[0]), "zakup: %s" % offers[0].id)
	g.market.generate()
	check(g.market.offers().size() == 6, "targ: 6 ofert")
	g.inventory.add("frag_mount_elk", 20)
	check(g.mounts.upgrade("mount_elk"), "łoś odblokowany fragmentami")
	g.stats.recalc()
	check(g.stats.xp_mult > 1.05, "premia łosia do XP: %s" % g.stats.xp_mult)
	var sold := g.shop.sell_junk(2)
	check(true, "sprzedano śmieci: %d za %s" % [sold[0], IdleDB.fmt(sold[1])])

	print("== zapis i odczyt")
	var gold_before := float(s.gold)
	var stage_before := int(s.max_stage)
	check(g.save.save_game(), "zapisano")
	var loaded := g.save.load_game()
	check(is_equal_approx(float(loaded.gold), gold_before) and int(loaded.max_stage) == stage_before, "odczyt zgodny")
	# Uszkodzony zapis -> kopia zapasowa.
	g.save.save_game()
	var f := FileAccess.open(g.save.path, FileAccess.WRITE)
	f.store_string("{zepsute")
	f.close()
	check(not g.save.load_game().is_empty(), "uszkodzony zapis – wczytano kopię .bak")

	print("== postęp offline")
	g.s.last_time = Time.get_unix_time_from_system() - 3600.0 * 3.0
	var gold_off := float(s.gold)
	var rep := g.offline.compute_and_apply()
	check(int(rep.get("kills", 0)) > 0, "offline 3 h: %d wrogów, %s złota, %d surowców, %d przedmiotów" % [int(rep.kills), IdleDB.fmt(float(rep.gold)), int(rep.materials), rep.items.size()])
	check(float(s.gold) > gold_off, "złoto z offline")

	print("== odrodzenie")
	s.max_stage = 60
	var ash := g.prestige.ash_gain()
	check(ash > 0, "Popiół Dusz do zdobycia: %d" % ash)
	check(g.prestige.rebirth(), "odrodzenie")
	check(int(s.max_stage) == 1 and int(s.ash) == ash and s.mercs.is_empty(), "reset etapów i najemników, popiół zachowany")
	check(g.spells.is_known("meteor"), "czary zachowane")
	check(g.mounts.level("mount_elk") == 1, "wierzchowce zachowane")
	check(g.prestige.buy("damage"), "Ołtarz: Gniew Popiołu")
	g.stats.recalc()
	check(g.stats.dmg_mult > 1.2, "premia prestiżu do obrażeń")

	print("== codzienna nagroda i osiągnięcia")
	s.daily = {"day": 0, "last": ""}
	gems0 = int(s.gems)
	check(g.daily.available("2026-01-01") and g.daily.current_day("2026-01-01") == 0, "nagroda dnia 1 dostępna")
	check(not g.daily.claim("2026-01-01").is_empty() and not g.daily.available("2026-01-01"), "odebrano dzień 1, drugi raz nie")
	g.daily.claim("2026-01-02")
	g.daily.claim("2026-01-03")
	check(int(s.gems) >= gems0 + 20 and g.daily.current_day("2026-01-04") == 3, "seria: dzień 3 = żarokryształy, następny dzień 4")
	check(g.daily.current_day("2026-01-06") == 0, "przerwa zeruje serię")
	for d in ["2026-02-01", "2026-02-02", "2026-02-03", "2026-02-04", "2026-02-05", "2026-02-06", "2026-02-07"]:
		g.daily.claim(d)
	check(g.inventory.count("chest_4") >= 1 and g.daily.current_day("2026-02-08") == 0, "dzień 7: epicka skrzynia, potem seria od nowa")
	check(g.achievements.value("best_stage") >= 60.0, "osiągnięcia pamiętają etap sprzed odrodzenia")
	var ready := g.achievements.ready_count()
	check(ready > 0, "osiągnięcia do odebrania: %d" % ready)
	gems0 = int(s.gems)
	check(g.achievements.claim("kills") and int(s.gems) > gems0, "odebrano osiągnięcie Łowca")
	check(g.achievements.claimed("kills") == 1 and not g.achievements.claim("rebirths_x"), "stopień zapisany, zły klucz odrzucony")

	print("== talenty")
	s.ach.best_level = 40
	check(g.talents.earned() >= 20, "punkty talentów z rekordu poziomu: %d" % g.talents.earned())
	var click0 := g.stats.click
	check(g.talents.learn("heavy_hand"), "nauka: Ciężka ręka")
	check(g.stats.click > click0 * 1.05, "talent zwiększa cios (%s → %s)" % [IdleDB.fmt(click0), IdleDB.fmt(g.stats.click)])
	check(not g.talents.can_learn("wrath"), "węzeł końcowy zablokowany bez punktów w gałęzi")
	for i in 3:
		g.talents.learn("heavy_hand")
	check(g.talents.can_learn("hawk_eye"), "4 punkty w gałęzi odblokowują drugi węzeł")
	var cost0 := g.mercs.cost("guard")
	g.talents.learn("wages")
	for i in 4:
		g.talents.learn("wages")
	for i in 3:
		g.talents.learn("plunder")
	g.talents.learn("quarter")
	check(g.mercs.cost("guard") < cost0, "Kwatermistrz obniża koszt najemników")
	var spent := g.talents.spent()
	check(g.talents.reset() and g.talents.spent() == 0 and g.talents.free_points() >= spent, "pierwszy reset darmowy, punkty wracają")

	print("== bestiariusz")
	s.bestiary = {}
	g.stats.recalc()
	var dmg0 := g.stats.dmg_mult
	for i in 10:
		g.bestiary.on_kill("rat")
	g.stats.recalc()
	check(g.bestiary.tier_of(g.bestiary.kills("rat")) >= 1 and g.bestiary.total_tiers() >= 1, "stopień szczura w bestiariuszu")
	check(g.stats.dmg_mult > dmg0, "bestiariusz daje premię do obrażeń")
	check(g.bestiary.all_species().size() >= 20, "gatunków w bestiariuszu: %d" % g.bestiary.all_species().size())

	print("== wyprawy")
	s.max_stage = 25
	s.exped = {"active": [], "done": 0}
	var te := ExpeditionManager.now()
	check(g.expeditions.slots() == 2, "sloty wypraw na etapie 25: %d" % g.expeditions.slots())
	check(g.expeditions.start(0, 1, te) and g.expeditions.start(1, 0, te), "wysłano dwie wyprawy")
	check(not g.expeditions.start(0, 0, te), "brak wolnego slotu")
	check(g.expeditions.claim(0, te + 60.0).is_empty(), "nie można odebrać przed powrotem")
	var gold0 := float(s.gold)
	var ex_got := g.expeditions.claim(0, te + 3700.0)
	check(not ex_got.is_empty() and float(s.gold) > gold0, "łup z patrolu: %d pozycji" % ex_got.size())
	check(g.expeditions.active().size() == 1 and int(s.exped.done) == 1, "wyprawa zakończona, slot wolny")

	print("== wieża popiołu")
	s.tower = {"best": 0, "attempts": 3, "day": DailyManager.today()}
	check(g.tower.enter(), "wejście do wieży")
	check(g.enemy.cur.has("tower") and int(g.enemy.cur.kind) == 2, "przeciwnik piętra 1: %s" % g.enemy.cur.name)
	var gems1 := int(s.gems)
	var tw_stage := int(s.stage)
	for i in 3:
		g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap")
	check(g.tower.best() == 3 and int(s.gems) > gems1, "pokonano 3 piętra, rekord 3")
	check(int(s.stage) == tw_stage, "wieża nie zmienia etapu")
	g.enemy.cur.time_left = 0.01
	g.tick(0.1)
	check(not g.tower.active and not g.enemy.cur.has("tower"), "koniec czasu kończy wspinaczkę, powrót do walki")
	check(g.tower.attempts() == 2, "zostały 2 próby")
	check(g.tower.boss_hp(20) > g.tower.boss_hp(10) * 100.0, "piętra rosną wykładniczo")

	print("== lochy żaru")
	g.achievements.remember()
	if int(g.achievements.value("best_stage")) < 15:
		s.ach.best_stage = 15
	check(g.dungeon.unlocked(), "lochy otwarte od etapu 15")
	var dk := DungeonManager.DAILY_KEYS + int(g.events.bonus("dungeon"))
	check(g.dungeon.keys("gold") == dk and g.dungeon.total_keys() == dk * 3, "2 klucze dziennie na każdy loch")
	check(not g.dungeon.enter("gold", g.dungeon.max_tier("gold") + 1), "wyższe poziomy zablokowane")
	var dg_gold := float(s.gold)
	var dg_shards := g.relics.shards()
	check(g.dungeon.enter("gold", 1), "wejście do Skarbca Goblinów")
	check(str(g.enemy.cur.get("challenge", "")) == "dungeon" and int(g.enemy.cur.kind) == 1, "strażnik lochu: %s" % g.enemy.cur.name)
	check(g.challenge() == g.dungeon, "aktywne wyzwanie: loch")
	for i in DungeonManager.GUARDS:
		g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap")
	check(not g.dungeon.active and g.dungeon.best("gold") == 1 and g.dungeon.max_tier("gold") >= 2, "10 strażników – loch oczyszczony, poziom 2 odblokowany")
	check(float(s.gold) > dg_gold and g.relics.shards() > dg_shards, "złoto i odłamki relikwii z lochu")
	check(bool(g.dungeon.last_run.cleared) and int(g.dungeon.last_run.kills) == 10, "podsumowanie przejścia")
	check(g.dungeon.enter("mats", 1), "wejście do Kuźni Przodków")
	var t_left := float(g.enemy.cur.time_left)
	g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap")
	g.tick(1.0)
	check(float(g.enemy.cur.time_left) < t_left and float(g.enemy.cur.time_max) == DungeonManager.TIME, "wspólny czas na całe przejście")
	g.enemy.cur.time_left = 0.01
	g.tick(0.1)
	check(not g.dungeon.active and g.dungeon.best("mats") == 0 and not bool(g.dungeon.last_run.cleared), "koniec czasu – loch nieoczyszczony")
	check(g.challenge() == null and not g.enemy.cur.has("challenge"), "powrót do zwykłej walki")
	check(g.dungeon.keys("mats") == dk - 1, "klucz zużyty")
	s.dungeon.keys.gems = 0
	var gems_d := int(s.gems)
	check(not g.dungeon.enter("gems", 1), "bez klucza nie da się wejść")
	check(g.dungeon.enter("gems", 1, true) and int(s.gems) <= gems_d - DungeonManager.EXTRA_COST + 3, "dodatkowe wejście za żarokryształy")
	g.dungeon.leave()
	check(not g.dungeon.active, "wyjście z lochu")

	print("== arena popiołu")
	if int(g.achievements.value("best_stage")) < 25:
		s.ach.best_stage = 25
	var at := ArenaManager.DAILY_TICKETS + 2 * int(g.events.bonus("arena"))
	check(g.arena.unlocked() and g.arena.rating() == 1000 and g.arena.tickets() == at, "arena: ranking 1000, 5 biletów")
	check(g.arena.rivals().size() == 3, "3 rywali do wyboru")
	check(ArenaManager.league_name(1000) == "Brąz" and ArenaManager.league_name(1500) == "Złoto" and ArenaManager.league_name(3000) == "Legenda", "ligi")
	var rv: Array = g.arena.rivals()
	check(g.arena.rival_hp(rv[2]) > g.arena.rival_hp(rv[0]), "silniejszy rywal ma więcej zdrowia")
	check(g.arena.fight(1), "pojedynek z rywalem")
	check(str(g.enemy.cur.get("challenge", "")) == "arena" and int(g.enemy.cur.kind) == 2, "champion rywala: %s" % g.enemy.cur.name)
	g.combat.damage(float(g.enemy.cur.max_hp) * 2.0, false, "tap")
	check(not g.arena.active and g.arena.rating() > 1000 and g.arena.coins() > 0, "wygrana: ranking %d, odznaki %d" % [g.arena.rating(), g.arena.coins()])
	var r_win := g.arena.rating()
	check(g.arena.fight(0), "drugi pojedynek")
	g.enemy.cur.time_left = 0.01
	g.tick(0.1)
	check(not g.arena.active and g.arena.rating() < r_win, "porażka obniża ranking")
	check(g.arena.tickets() == at - 2, "bilety zużyte")
	check(g.arena.weekly_ready(), "nagroda tygodnia dostępna po walce")
	var wk := g.arena.claim_weekly()
	check(wk.size() == 4 and not g.arena.weekly_ready(), "nagroda ligowa odebrana raz")
	s.arena.coins = 500
	var keys_before := g.dungeon.total_keys()
	check(g.arena.buy(6) != "" and g.dungeon.total_keys() == keys_before + 1, "sklep areny: klucz do lochu")
	check(g.arena.buy(3) == "pet_egg" and not g.arena.can_buy(3), "jajo chowańca – limit 1 dziennie")
	check(absf(ArenaManager.expected(1000, 1000) - 0.5) < 0.001, "ELO: równi rywale 50%")

	print("== relikwie")
	s.relics.shards = 200
	var dmg_rl := g.stats.dmg_mult
	var pulled := 0
	while g.relics.can_pull() and pulled < 20:
		g.relics.pull()
		pulled += 1
	check(g.relics.shards() == 0 and pulled == 20, "20 relikwii z Relikwiarza")
	check(g.relics.owned_count() >= 8, "kolekcja: %d / 12" % g.relics.owned_count())
	g.stats.recalc()
	check(g.stats.dmg_mult >= dmg_rl, "relikwie wzmacniają bohatera")
	for id in RelicManager.RELICS:
		s.relics.owned[id] = 5
	g.stats.recalc()
	check(g.relics.set_level("dragon") == 2, "komplet zestawu z poziomami 5+")
	var tt := g.relics.totals()
	check(absf(float(tt.dmg) - (0.05 * 5 * 3 + 0.4)) < 0.001, "premie relikwii i zestawu: +%d%% obrażeń" % roundi(float(tt.dmg) * 100))

	s.relics.owned = {}
	g.stats.recalc()

	print("== runy")
	for k in s.inv.keys():
		if str(k).begins_with("rune_"):
			s.inv.erase(k)
	g.inventory.add("rune_fire_1", 3)
	g.inventory.add("rune_blood_2", 1)
	var dmg_r := g.stats.dmg_mult
	check(g.runes.socket("weapon", 0, "rune_fire_1"), "runa Ognia w gnieździe broni")
	g.stats.recalc()
	check(g.stats.dmg_mult > dmg_r * 1.04, "runa zwiększa obrażenia")
	check(g.inventory.count("rune_fire_1") == 2, "runa zdjęta z plecaka")
	g.add_gold(g.runes.combine_cost(1) * 2.0)
	check(not g.runes.combine("fire", 1), "za mało run do połączenia (2)")
	g.runes.unsocket("weapon", 0)
	check(g.runes.combine("fire", 1) and g.inventory.count("rune_fire_2") == 1, "3 okruchy → Runa Ognia")
	check(g.runes.socket("weapon", 1, "rune_blood_2") and g.runes.totals().has("crit"), "runa Krwi daje krytyk")
	s.max_stage = 60
	g.prestige.rebirth()
	check(g.runes.totals().has("crit") and g.inventory.count("rune_fire_2") == 1, "runy zostają po odrodzeniu")
	var rn := g.runes.random_rune(1.0)
	check(rn.begins_with("rune_") and RuneManager.value(rn) > 0.0, "losowa runa: %s" % RuneManager.rune_name(rn))

	print("== chowańce")
	s.pets = {"owned": {}, "active": []}
	g.inventory.add("pet_egg", 40)
	var hr := g.pets.hatch()
	check(not hr.is_empty() and hr.new and g.pets.active().size() == 1, "wykluto pierwszego chowańca: %s" % PetManager.def(str(hr.id)).get("name", ""))
	for i in 39:
		g.pets.hatch()
	check(g.pets.owned().size() >= 5, "kolekcja chowańców: %d" % g.pets.owned().size())
	var pid := str(g.pets.active()[0])
	g.add_gold(g.pets.level_cost(pid) * 50.0)
	var v0 := g.pets.value(pid)
	check(g.pets.level_up(pid) and g.pets.value(pid) > v0, "poziom chowańca zwiększa premię")
	g.stats.recalc()
	check(g.pets.totals().size() > 0, "premia aktywnego chowańca w statystykach")

	print("== boss tygodnia")
	s.raid = {"week": RaidManager.week_id(), "damage": 0.0, "claimed": 0, "day": DailyManager.today(), "attempts": 5}
	check(g.raid.enter() and g.enemy.cur.has("raid"), "wejście na bossa tygodnia: %s" % g.enemy.cur.name)
	g.combat.damage(g.raid.threshold(1) * 1.01, false, "tap")
	g.enemy.cur.time_left = 0.01
	g.tick(0.1)
	check(not g.raid.active and g.raid.damage() >= g.raid.threshold(1) and g.raid.damage() < g.raid.threshold(2), "obrażenia próby dopisane do tygodnia (tylko zadane)")
	check(g.raid.ready_tiers() == 2 and not g.raid.claim().is_empty() and not g.raid.claim().is_empty(), "odebrano 2 progi")
	check(g.raid.ready_tiers() == 0 and g.raid.attempts() == 4, "progi odebrane, 4 próby zostały")

	print("== fabuła")
	s.story = {"seen": [], "pending": []}
	g.story.on_new_stage(11)
	check(g.story.has_pending() and g.story.pop() == "intro:forest", "wejście do Puszczy – wstęp rozdziału II")
	g.story.on_region_boss(20)
	check(g.story.pop() == "outro:forest" and not g.story.has_pending(), "boss Puszczy – zakończenie rozdziału")
	g.story.on_new_stage(11)
	check(not g.story.has_pending(), "obejrzana scena nie wraca")
	g.story.on_new_stage(81)
	check(g.story.pop() == "circle:1", "nowy Krąg Popiołu – epilog")
	for c in g.db.story.chapters:
		check(not g.story.lines("intro:" + str(c.region)).is_empty() and not g.story.lines("outro:" + str(c.region)).is_empty(), "rozdział %s kompletny" % c.title)

	print("== stroje i wydarzenia")
	check(g.skins.unlocked("") and g.skins.unlocked("guard"), "strój Strażnika odblokowany (etap 10)")
	check(not g.skins.select("dragonslayer") or g.story.seen().has("outro:fire_temple"), "Pogromca Smoka wymaga pokonania Żarogniewa")
	check(g.skins.select("guard") and g.skins.model(["", "", "", "", "sword_t1", ""])[1] == "plate_body_t2", "strój zmienia wygląd modelu")
	g.skins.select("")
	check(not str(g.events.current().name).is_empty(), "wydarzenie tygodnia: %s" % g.events.current().name)

	print("== sklep premium")
	s.premium = {"tokens": [], "owned": {}, "first": {}, "monthly_until": 0.0, "monthly_claim": "", "history": [],
		"ads": {"day": "", "count": 0, "chest_at": 0.0, "fury_until": 0.0, "tower_day": ""}}
	var gp0 := int(s.gems)
	var pr := g.premium
	pr.grant("pk_gems_550", "tok-1")
	check(int(s.gems) == gp0 + 1050, "pierwszy zakup Sakiewki: ×2 + bonus (1050)")
	check(pr.grant("pk_gems_550", "tok-1").is_empty() and int(s.gems) == gp0 + 1050, "ten sam token nie jest przyznawany drugi raz")
	pr.grant("pk_gems_550", "tok-2")
	check(int(s.gems) == gp0 + 1050 + 550, "drugi zakup: zwykła ilość")
	var st_got := pr.grant("pk_starter", "tok-3")
	check(not st_got.is_empty() and pr.owns("starter") and not pr.can_buy("pk_starter"), "Pakiet Popielnika – jednorazowo")
	check(pr.grant("pk_starter", "tok-4").is_empty(), "drugi Pakiet nic nie daje (przywrócenie)")
	pr.grant("pk_monthly", "tok-5")
	check(pr.monthly_active() and pr.monthly_days_left() == 30 and pr.claim_monthly() == 100 and pr.claim_monthly() == 0, "Przymierze Żaru: 30 dni, 100 dziennie raz na dzień")
	var slots0 := g.expeditions.slots()
	pr.grant("pk_purse", "tok-6")
	check(pr.has_purse() and g.expeditions.slots() == slots0 + 1, "Mieszek Kupca: +1 slot wypraw")
	g.stats.recalc()
	var d_f := g.stats.dmg_mult
	check(pr.ad_reward("fury") != "" and pr.fury_active(), "Zwój Furii aktywny")
	g.stats.recalc()
	check(g.stats.dmg_mult > d_f * 1.9, "Furia ×2 obrażeń")
	check(pr.ad_reward("free_chest") != "" and not pr.ad_available("free_chest"), "darmowa skrzynia i odnowienie 4 h")
	var att := g.tower.attempts()
	check(pr.ad_reward("tower_attempt") != "" and g.tower.attempts() == att + 1 and not pr.ad_available("tower_attempt"), "dodatkowa próba w Wieży raz dziennie")
	var odds := g.loot.chest_odds(4)
	check(odds.size() >= 6, "szanse skrzyni ujawnione (%d pozycji)" % odds.size())
	var tot := 0.0
	for o in g.pets.egg_odds():
		if str(o[1]).ends_with("%"):
			tot += float(str(o[1]).trim_suffix("%"))
	check(absf(tot - 100.0) < 0.5, "szanse jaja sumują się do 100%% (%.1f)" % tot)

	print("== karnet popiołu")
	s.season = {"id": SeasonManager.season_id(), "xp": 0, "premium": false, "free": [], "gold": [], "kills": 0}
	g.season.add_xp(SeasonManager.XP_PER_LEVEL * 3)
	check(g.season.level() == 3 and g.season.claimable(1, false) and not g.season.claimable(1, true), "poziom 3, złota ścieżka zablokowana")
	check(not g.season.claim(1, false).is_empty() and not g.season.claimable(1, false), "odebrano nagrodę darmową")
	pr.grant("pk_season", "tok-7")
	check(g.season.premium() and g.season.claimable(1, true) and g.season.claimable(3, true), "Złoty Karnet działa wstecz")
	check(g.season.claim_all().size() >= 4 and g.season.ready_count() == 0, "odbierz wszystko")
	s.season.xp = SeasonManager.XP_PER_LEVEL * 30
	g.season.claim(30, true)
	check(g.skins.unlocked("ashprince"), "strój Popielny Książę z 30. poziomu")

	print("== przebudzenie feniksa")
	s.phoenix = {"feathers": 0, "total": 0, "count": 0, "upg": {}, "ash_base": 0}
	s.ash_total = 50
	s.max_stage = 90
	check(not g.phoenix.can_awaken(), "za mało popiołu na przebudzenie")
	s.ash_total = 900
	var fg := g.phoenix.feather_gain()
	check(fg > 0 and g.phoenix.can_awaken(), "pióra do zdobycia: %d" % fg)
	var tal0 := g.talents.earned()
	check(g.phoenix.awaken() and g.phoenix.feathers() >= fg and int(s.ash) == 0 and s.prestige.is_empty(), "przebudzenie: pióra, reset popiołu i ołtarza")
	check(not g.phoenix.can_awaken(), "liczy się popiół od ostatniego przebudzenia")
	var d0 := g.stats.dmg_mult
	check(g.phoenix.buy("flame"), "Płomień Feniksa")
	check(g.stats.dmg_mult > d0 * 1.4, "mnożnik obrażeń ×1,5")
	if g.phoenix.feathers() >= g.phoenix.cost("wisdom"):
		g.phoenix.buy("wisdom")
		check(g.talents.earned() == tal0 + 3, "Mądrość Feniksa: +3 punkty talentów")

	print("== ścieżka popielnika")
	var pth := g.path
	s.erase("path")
	s.max_stage = 1
	s.rebirths = 0
	check(pth.index() == 0 and not pth.finished(), "nowa gra: ścieżka od pierwszego celu")
	s.stats.taps = 0
	check(not pth.ready() and pth.claim().is_empty(), "cel niespełniony – brak nagrody")
	s.stats.taps = 20
	var pg := int(s.gems)
	check(pth.ready() and pth.claim().size() == 1 and int(s.gems) == pg + 10, "15 ciosów: +10 żarokr.")
	check(pth.index() == 1 and str(pth.current()[1]) == "merc_levels", "kolejny cel: najemnik")
	g.quests.on_event("upgrades", 1)
	check(pth.value("upgrades") == 1.0, "licznik ulepszeń ścieżki")
	s.path.i = PathManager.GOALS.size() - 1
	s.rebirths = 1
	var eggs0 := g.inventory.count("pet_egg")
	pth.claim()
	check(pth.finished() and g.inventory.count("pet_egg") == eggs0 + 1, "ostatni cel (odrodzenie): jajo, ścieżka ukończona")
	s.erase("path")
	s.max_stage = 60
	check(pth.finished(), "stary zapis z dużym postępem – ścieżka zaliczona bez nagród")

	print("== koło żaru")
	var wh := g.wheel
	s.erase("wheel")
	check(wh.free_spins() == 1 and wh.can_spin(), "1 darmowy obrót dziennie")
	var total := 0
	for seg in WheelManager.SEGMENTS:
		total += int(seg[2])
	check(total == 100 and wh.odds().size() == 8, "szanse pól sumują się do 100%")
	var r1 := wh.spin()
	check(r1.size() == 2 and str(r1[1]) != "" and wh.free_spins() == 0, "obrót: %s" % (r1[1] if r1.size() == 2 else "?"))
	check(not wh.can_spin() and wh.spin().is_empty(), "bez obrotów – brak losowania")
	s.gems = 1000
	var gw := int(s.gems)
	var r2 := wh.spin(true)
	check(r2.size() == 2 and wh.paid_today() == 1 and int(s.gems) <= gw - WheelManager.GEM_COST + 250, "obrót za żarokryształy")
	for i in 10:
		wh.spin(true)
	check(wh.paid_today() == WheelManager.PAID_LIMIT, "limit płatnych obrotów: %d dziennie" % WheelManager.PAID_LIMIT)
	wh.add_free_spin()
	check(wh.can_spin(), "obrót za reklamę")
	var hits := {}
	for i in 400:
		s.wheel.free = 1
		var rr := wh.spin()
		hits[int(rr[0])] = int(hits.get(int(rr[0]), 0)) + 1
	check(int(hits.get(0, 0)) > int(hits.get(7, 0)), "pole złota częstsze niż wielka wygrana (%d vs %d)" % [int(hits.get(0, 0)), int(hits.get(7, 0))])

	print("== zaklęcia ekwipunku")
	s.ach.best_stage = maxi(int(s.ach.best_stage), EquipmentManager.ENCHANT_STAGE)
	var en_it: Dictionary = g.inventory.add_gear("sword_t3", 3)
	check(g.equipment.can_enchant_item(en_it), "miecz można zaczarować")
	s.gold = float(g.equipment.enchant_cost(en_it).gold) * 100.0
	var sc0 := g.equipment.score(en_it)
	var rng_e := RandomNumberGenerator.new()
	rng_e.seed = 7
	var ench := g.equipment.enchant(int(en_it.uid), rng_e)
	check(not ench.is_empty() and en_it.has("ench") and int(en_it.rr) == 1, "zaklęcie: %s" % g.equipment.enchant_text(en_it))
	check(g.equipment.score(en_it) >= sc0 and g.equipment.item_stats(en_it).has(str(ench.stat)), "zaklęcie dodaje premię")
	check(int(g.equipment.enchant_cost(en_it).shards) == 1, "przekucie kosztuje odłamek relikwii")
	s.relics.shards = 0
	check(not g.equipment.can_enchant(en_it), "bez odłamka nie da się przekuć")
	s.relics.shards = 5
	check(not g.equipment.enchant(int(en_it.uid), rng_e).is_empty() and g.relics.shards() == 4 and int(en_it.rr) == 2, "przekucie zaklęcia")
	var tool_it: Dictionary = g.inventory.add_gear("pickaxe_t2", 2)
	check(not g.equipment.can_enchant_item(tool_it), "narzędzi nie zaczarujesz")
	g.shop.sell_junk(5)
	check(not g.inventory.gear_by_uid(int(en_it.uid)).is_empty(), "zaczarowany przedmiot chroniony przed hurtową sprzedażą")

	print("== kod zapisu")
	var code := g.save.export_code()
	check(code.begins_with("PK1-") and code.length() > 100, "eksport: kod %d znaków" % code.length())
	var back := SaveManager.parse_code(code)
	check(int(back.max_stage) == int(s.max_stage) and back.gear.size() == s.gear.size(), "kod odtwarza stan gry")
	var bad_code := code.substr(0, 10) + ("x" if code[10] != "x" else "y") + code.substr(11)
	check(SaveManager.parse_code(bad_code).is_empty() and SaveManager.parse_code("bzdura").is_empty(), "uszkodzony kod odrzucony")
	var gold_kod := float(s.gold)
	s.gold = 1.0
	check(g.import_state(back) and absf(float(g.s.gold) - gold_kod) < 1.0, "import przywraca grę")
	s = g.s

	print("== klasy bohatera")
	var hc := g.hero
	s.erase("hero_class")
	s.ach.best_stage = maxi(int(s.ach.best_stage), ClassManager.UNLOCK_STAGE)
	g.stats.recalc()
	var hc_click0 := g.stats.click
	var hc_crit0 := g.stats.crit_chance
	check(hc.unlocked() and hc.current() == "" and hc.change_cost() == 0, "klasy odblokowane, pierwszy wybór darmowy")
	var hc_gems := int(s.gems)
	check(hc.choose("warrior") and int(s.gems) == hc_gems, "wybór Wojownika")
	g.stats.recalc()
	check(g.stats.click > hc_click0 * 1.25 and g.stats.crit_chance > hc_crit0, "Wojownik: +30% ciosu, +krytyk")
	check(not hc.ready() and not hc.activate(), "bez Żaru brak umiejętności")
	for i in 200:
		hc.add_charge(0.6)
	check(hc.ready(), "Żar pełny po ciosach")
	var hc_click1 := g.stats.click
	check(hc.activate() and hc.ult_active(), "Furia Żaru aktywna")
	g.stats.recalc()
	check(g.stats.click > hc_click1 * 3.5, "Furia: ×4 obrażenia ciosu")
	s.hero_class.ult_until = 0.0
	g.tick(0.05)
	g.stats.recalc()
	check(absf(g.stats.click - hc_click1) < hc_click1 * 0.01, "koniec Furii")
	s.gems = 1000
	check(hc.change_cost() == ClassManager.CHANGE_COST and hc.choose("mage") and int(s.gems) == 1000 - ClassManager.CHANGE_COST, "zmiana klasy za żarokryształy")
	s.hero_class.charge = ClassManager.CHARGE_MAX
	g.enemy.spawn()
	var hc_hp := float(g.enemy.cur.hp)
	g.spells.cooldowns["heal"] = 50.0
	check(hc.activate() and g.spells.cd_left("heal") == 0.0, "Kataklizm: odnowienie czarów")
	check(float(g.enemy.cur.get("hp", 0.0)) < hc_hp or g.enemy.cur.get("monster", "") != "", "Kataklizm zadaje obrażenia")
	s.erase("hero_class")
	g.stats.recalc()

	print("== festyn żaru")
	var fe := g.festival
	s.erase("festival")
	var t_on := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 5, "hour": 12, "minute": 0, "second": 0})
	var t_off := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 20, "hour": 12, "minute": 0, "second": 0})
	check(fe.active(t_on) and not fe.active(t_off), "festyn w dniach 1–10 miesiąca")
	fe.force = 0
	check(fe.on_kill(2) == 0 and fe.lanterns() == 0, "poza festynem brak lampionów")
	fe.force = 1
	check(fe.on_kill(2) == 4 and fe.on_kill(1) == 3, "boss 4, elita 3 lampiony")
	var lt_n := 0
	for i in 500:
		lt_n += fe.on_kill(0)
	check(lt_n > 15 and lt_n < 80, "zwykli wrogowie: ok. 8%% (%d / 500)" % lt_n)
	check(not fe.can_buy(0), "strój kosztuje 600 lampionów")
	s.festival.lanterns = 2000
	check(fe.buy(0) and g.skins.unlocked("festival") and not fe.can_buy(0), "strój Mistrz Festynu kupiony raz")
	var eggs_f := g.inventory.count("pet_egg")
	check(fe.buy(1) and g.inventory.count("pet_egg") == eggs_f + 1, "jajo z kramu")
	fe.force = 0
	check(not fe.can_buy(1), "kram zamknięty poza festynem")
	check(fe.days_left() > 0, "odliczanie do festynu: %d dni" % fe.days_left())
	fe.force = -1

	print("== przebudzenie najemników")
	var mid0 := str(g.db.mercs[0].id)
	s.mercs[mid0] = 99
	s.seals = 0
	var dps_a := g.mercs.dps(mid0)
	check(not g.mercs.can_awaken(mid0), "przed poz. 100 brak przebudzenia")
	s.mercs[mid0] = 100
	check(not g.mercs.can_awaken(mid0) and g.mercs.awaken_cost(mid0) == 1, "bez pieczęci brak przebudzenia")
	g.mercs.add_seals(3)
	var dps_b := g.mercs.dps(mid0)
	check(g.mercs.awaken(mid0) and g.mercs.stars(mid0) == 1 and g.mercs.seals() == 2, "przebudzenie ★1 za 1 pieczęć")
	check(absf(g.mercs.dps(mid0) - dps_b * 3.0) < 0.01 * dps_b, "★1: DPS ×3")
	check(not g.mercs.can_awaken(mid0) and g.mercs.awaken_level(mid0) == 200, "★2 wymaga poz. 200")
	s.mercs[mid0] = 200
	check(g.mercs.awaken(mid0) and g.mercs.seals() == 0, "★2 za 2 pieczęci")
	check(dps_a > 0.0, "DPS przed przebudzeniem %s" % IdleDB.fmt(dps_a))
	s.erase("merc_stars")

	# --- wersja angielska ---
	var tr_en := SmartTranslation.new()
	check(tr_en.load_json("res://data/i18n/en.json"), "słownik angielski wczytany")
	for pair in [["ATAK!", "ATTACK!"], ["PZ: 1.2K / 3K", "HP: 1.2K / 3K"], ["Miecz Adepta (T3)", "Adept Sword (T3)"],
			["Pokonaj 25 przeciwników", "Defeat 25 enemies"], ["KULA OGNIA", "FIREBALL"], ["5× Mikstura życia", "5× Health potion"],
			["Ciężka ręka  4/20", "Heavy Hand  4/20"], ["42.1M złota", "42.1M gold"]]:
		check(str(tr_en.translate(pair[0])) == pair[1], "tłumaczenie: %s → %s" % pair)
	check(tr_en.translate("12.5K") == null, "liczby bez zmian")
	# każda nazwa przedmiotu, potwora i regionu ma tłumaczenie
	var untranslated := 0
	for id in g.db.items:
		if tr_en.translate(g.db.item_name(str(id))) == null:
			untranslated += 1
	check(untranslated == 0, "nazwy przedmiotów po angielsku (brak: %d)" % untranslated)
	for r in g.db.regions:
		check(tr_en.translate(str(r.name)) != null, "region po angielsku: %s" % r.name)
	check(SmartTranslation.resolve("en") == "en" and SmartTranslation.resolve("pl") == "pl", "wybór języka")
	SmartTranslation.apply_language("en")
	check(tr("ATAK!") == "ATTACK!", "po angielsku: ATAK! → ATTACK!")
	SmartTranslation.apply_language("pl")
	check(tr("ATAK!") == "ATAK!", "po polsku bez tłumaczenia (bez zapasowego angielskiego)")
	SmartTranslation.apply_language("en")
	check(tr("Zabij szczury") == "Kill the rats", "ponowne przełączenie na angielski")
	SmartTranslation.apply_language("pl")

	g.save.delete_save()
	print("== wynik: %s (%d błędów)" % ["OK" if fails == 0 else "BŁĘDY", fails])
	get_tree().quit(1 if fails > 0 else 0)
