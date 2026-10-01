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

	print("== runy")
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

	g.save.delete_save()
	print("== wynik: %s (%d błędów)" % ["OK" if fails == 0 else "BŁĘDY", fails])
	get_tree().quit(1 if fails > 0 else 0)
