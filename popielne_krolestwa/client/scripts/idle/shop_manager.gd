class_name ShopManager
extends RefCounted
## Sklep (Kupiec): mikstury, surowce odblokowanych tierów, podstawowy ekwipunek, wzmocnienia
## i skrzynie za żarokryształy; skup łupu. Ceny skalują się z etapem (wartości MMO są absolutne,
## a gospodarka clickera rośnie wykładniczo).

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


## Skala cen tieru: złoto za wroga w środku regionu o tym tierze.
func tier_price(t: int) -> float:
	return ProgressionManager.gold_for(gm.progression.tier_stage(t))


func stage_price() -> float:
	return ProgressionManager.gold_for(int(gm.s.max_stage))


## Oferta: [{id, name, icon_item, kind, price, currency ("gold"/"gems"), amount, text}].
func offers() -> Array:
	var out: Array = []
	var sp := stage_price()
	out.append({"id": "hp_potion", "kind": "item", "amount": 5, "price": ceilf(sp * 4.0), "currency": "gold", "text": "Leczy 30% zdrowia w walce z bossem."})
	out.append({"id": "mp_potion", "kind": "item", "amount": 5, "price": ceilf(sp * 4.0), "currency": "gold", "text": "Odnawia 50% many."})
	if int(gm.s.max_stage) >= 30:
		out.append({"id": "great_hp_potion", "kind": "item", "amount": 5, "price": ceilf(sp * 12.0), "currency": "gold", "text": "Leczy 60% zdrowia."})
		out.append({"id": "great_mp_potion", "kind": "item", "amount": 5, "price": ceilf(sp * 12.0), "currency": "gold", "text": "Odnawia całą manę."})
	var maxt := gm.progression.loot_tier(int(gm.s.max_stage))
	for kind in IdleDB.MATERIAL_KINDS:
		out.append({"id": "%s_t%d" % [kind, maxt], "kind": "item", "amount": 10, "price": ceilf(tier_price(maxt) * 6.0), "currency": "gold", "text": "Surowiec do ulepszeń i rafinacji."})
	for base in ["sword", "bow", "staff", "shield", "plate_body", "leather_body", "cloth_body"]:
		out.append({"id": "%s_t%d" % [base, maxt], "kind": "gear", "amount": 1, "price": ceilf(tier_price(maxt) * 40.0), "currency": "gold", "text": "Zwykła jakość."})
	out.append({"id": "boost_gold", "kind": "boost", "stat": "gold", "power": 1.0, "minutes": 30, "amount": 1, "price": 25, "currency": "gems", "name": "Sakwa Kupca", "text": "+100% złota przez 30 min"})
	out.append({"id": "boost_damage", "kind": "boost", "stat": "damage", "power": 1.0, "minutes": 30, "amount": 1, "price": 30, "currency": "gems", "name": "Róg Wojenny", "text": "+100% obrażeń przez 30 min"})
	out.append({"id": "boost_xp", "kind": "boost", "stat": "xp", "power": 1.0, "minutes": 30, "amount": 1, "price": 20, "currency": "gems", "name": "Księga Mędrca", "text": "+100% doświadczenia przez 30 min"})
	out.append({"id": "chest_3", "kind": "item", "amount": 1, "price": 40, "currency": "gems", "text": "Rzadka skrzynia."})
	out.append({"id": "chest_4", "kind": "item", "amount": 1, "price": 120, "currency": "gems", "text": "Epicka skrzynia."})
	return out


func buy(o: Dictionary) -> bool:
	var paid := false
	if str(o.currency) == "gems":
		paid = gm.spend_gems(int(o.price))
	else:
		paid = gm.spend_gold(float(o.price))
	if not paid:
		return false
	match str(o.kind):
		"item":
			gm.inventory.add(str(o.id), int(o.amount))
			gm.loot_gained.emit([[str(o.id), int(o.amount), 0]])
		"gear":
			var it := gm.inventory.add_gear(str(o.id), 1)
			if not it.is_empty():
				gm.loot_gained.emit([[str(it.id), 1, 1]])
		"boost":
			gm.crafting.add_boost(str(o.stat), float(o.power), float(o.minutes) * 60.0)
	gm.audio.play("coin")
	return true


# --- Skup ----------------------------------------------------------------------

## Cena sprzedaży przedmiotu liczonego (za sztukę).
func sell_price(id: String) -> float:
	var def := gm.db.item(id)
	var cat := str(def.get("category", "misc"))
	var t := maxi(1, int(def.get("tier", 1)))
	var base := tier_price(t)
	match cat:
		"resource":
			return ceilf(base * 0.15)
		"material":
			return ceilf(base * 0.6)
		"consumable":
			return ceilf(stage_price() * 0.5)
	if id.begins_with("chest_") or id.begins_with("frag_"):
		return 0.0
	# Trofea bossów i kości – według wartości MMO względem tieru.
	return ceilf(base * maxf(0.2, float(def.get("value", 1)) / 20.0))


func sell_price_gear(it: Dictionary) -> float:
	var t := clampi(IdleDB.tier_of(str(it.id)), 1, 8)
	return ceilf(tier_price(t) * 8.0 * IdleDB.QUALITY_MULT[int(it.q)] * (1.0 + 0.2 * int(it.lvl)))


func sell(id: String, n: int) -> bool:
	n = mini(n, gm.inventory.count(id))
	var p := sell_price(id)
	if n <= 0 or p <= 0.0:
		return false
	gm.inventory.remove(id, n)
	gm.add_gold(p * n)
	gm.audio.play("coin")
	return true


func sell_gear(uid: int) -> bool:
	if gm.equipment.is_equipped(uid):
		return false
	var it := gm.inventory.gear_by_uid(uid)
	if it.is_empty():
		return false
	gm.inventory.remove_gear(uid)
	gm.add_gold(sell_price_gear(it))
	gm.audio.play("coin")
	return true


## Sprzedaż niezałożonego ekwipunku do danej rzadkości (bez ulepszonego i narzędzi). Zwraca [liczba, złoto].
func sell_junk(max_rarity: int) -> Array:
	var n := 0
	var gold := 0.0
	for it in gm.s.gear.duplicate():
		var uid := int(it.uid)
		if gm.equipment.is_equipped(uid) or int(it.q) > max_rarity or int(it.lvl) > 0 or it.has("ench") or gm.equipment.is_tool(str(it.id)):
			continue
		gold += sell_price_gear(it)
		gm.inventory.remove_gear(uid)
		n += 1
	if n > 0:
		gm.add_gold(gold)
		gm.audio.play("coin")
	return [n, gold]
