class_name MarketManager
extends RefCounted
## Targ (uproszczony rynek MMO): 6 ofert kupców trzech miast, odnawianych co 30 minut –
## tańsze paczki surowców albo skup surowca po podwyższonej cenie.

const REFRESH := 1800.0
const OFFERS := 6

var gm: IdleGame
var _rng := RandomNumberGenerator.new()


func _init(g: IdleGame) -> void:
	gm = g
	_rng.randomize()


func ensure_offers() -> void:
	var m: Dictionary = gm.s.market
	var now := Time.get_unix_time_from_system()
	if m.get("offers", []).is_empty() or now >= float(m.get("refresh_at", 0.0)):
		generate()


func time_left() -> float:
	return maxf(0.0, float(gm.s.market.get("refresh_at", 0.0)) - Time.get_unix_time_from_system())


func generate() -> void:
	var offers: Array = []
	var cities: Array = gm.db.cities.values()
	var maxt := gm.progression.loot_tier(int(gm.s.max_stage))
	for i in OFFERS:
		var city: Dictionary = cities[_rng.randi() % cities.size()]
		var trader := str(city.npcNames.market)
		var t := _rng.randi_range(maxi(1, maxt - 2), maxt)
		var kind := str(IdleDB.MATERIAL_KINDS[_rng.randi() % 5])
		var refined := _rng.randf() < 0.35
		var id := "%s_t%d" % [IdleDB.REFINED[kind] if refined else kind, t]
		var unit := gm.shop.sell_price(id)
		if _rng.randf() < 0.55:
			var amount := _rng.randi_range(10, 30)
			offers.append({"type": "sell", "id": id, "amount": amount, "price": ceilf(unit * amount * _rng.randf_range(2.5, 4.0)),
				"trader": trader, "city": str(city.name), "done": false})
		else:
			var amount := _rng.randi_range(5, 20)
			offers.append({"type": "buy", "id": id, "amount": amount, "price": ceilf(unit * amount * _rng.randf_range(1.6, 2.4)),
				"trader": trader, "city": str(city.name), "done": false})
	gm.s.market = {"offers": offers, "refresh_at": Time.get_unix_time_from_system() + REFRESH}
	gm.changed.emit("market")


func offers() -> Array:
	ensure_offers()
	return gm.s.market.offers


## „sell” – kupiec sprzedaje graczowi paczkę; „buy” – kupiec skupuje od gracza.
func accept(index: int) -> bool:
	var list: Array = offers()
	if index < 0 or index >= list.size():
		return false
	var o: Dictionary = list[index]
	if bool(o.done):
		return false
	if str(o.type) == "sell":
		if not gm.spend_gold(float(o.price)):
			return false
		gm.inventory.add(str(o.id), int(o.amount))
		gm.loot_gained.emit([[str(o.id), int(o.amount), 0]])
	else:
		if not gm.inventory.remove(str(o.id), int(o.amount)):
			return false
		gm.add_gold(float(o.price))
	o.done = true
	gm.audio.play("coin")
	gm.changed.emit("market")
	return true
