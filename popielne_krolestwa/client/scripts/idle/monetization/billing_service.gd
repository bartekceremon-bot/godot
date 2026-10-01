class_name BillingService
extends Node
## Płatności w aplikacji. Na Androidzie – wtyczka GodotGooglePlayBilling (singleton
## "GodotGooglePlayBilling", dodawana przy budowaniu w CI, patrz docs/GOOGLE_PLAY.md).
## Poza Google Play (przeglądarka, komputer, testy) – tryb testowy: zakup po potwierdzeniu,
## bez pobierania pieniędzy, wyraźnie oznaczony w sklepie.
##
## Sygnały: ready_changed, prices_updated, purchase_ok(product_id, token), purchase_failed(product_id, reason).

signal ready_changed(ok: bool)
signal prices_updated
signal purchase_ok(product_id: String, token: String)
signal purchase_failed(product_id: String, reason: String)

const SINGLETON := "GodotGooglePlayBilling"
const OK := 0
const USER_CANCELED := 1
const ITEM_ALREADY_OWNED := 7
const PURCHASED := 1
const PENDING := 2

## "google_play" | "sandbox" | "none"
var backend := "none"
var connected := false
## product_id -> cena sformatowana przez Google Play ("24,99 zł").
var prices: Dictionary = {}
var _play: Object
var _product_ids: PackedStringArray = []
var _consumable: Dictionary = {}
var _pending: Dictionary = {}


func setup(products: Array, allow_sandbox: bool) -> void:
	for p in products:
		_product_ids.append(str(p.id))
		_consumable[str(p.id)] = bool(p.consumable)
	if Engine.has_singleton(SINGLETON):
		backend = "google_play"
		_play = Engine.get_singleton(SINGLETON)
		if _play.has_method("initPlugin"):
			_play.initPlugin()
		for sig in ["connected", "disconnected", "connect_error", "query_product_details_response", "query_purchases_response",
				"on_purchase_updated", "consume_purchase_response", "acknowledge_purchase_response"]:
			if _play.has_signal(sig):
				_play.connect(sig, Callable(self, "_on_" + sig))
		_play.startConnection()
	elif allow_sandbox:
		backend = "sandbox"
		connected = true
		ready_changed.emit.call_deferred(true)
	else:
		backend = "none"


func available() -> bool:
	return backend != "none" and connected


func is_sandbox() -> bool:
	return backend == "sandbox"


func price_of(product_id: String, fallback: String) -> String:
	return str(prices.get(product_id, fallback))


## Rozpoczyna zakup. Wynik przychodzi sygnałem purchase_ok / purchase_failed.
func buy(product_id: String) -> void:
	match backend:
		"google_play":
			if not connected:
				purchase_failed.emit(product_id, "Brak połączenia ze Sklepem Google Play.")
				return
			var r: Dictionary = _play.purchase(product_id, "", "", false)
			if int(r.get("response_code", -1)) != OK:
				purchase_failed.emit(product_id, _reason(int(r.get("response_code", -1)), str(r.get("debug_message", ""))))
		"sandbox":
			purchase_ok.emit.call_deferred(product_id, "sandbox-%s-%d" % [product_id, Time.get_ticks_usec()])
		_:
			purchase_failed.emit(product_id, "Zakupy są dostępne w wersji z Google Play.")


## Przywraca zakupy jednorazowe i dokańcza nieprzyznane (np. po zamknięciu aplikacji w trakcie).
func restore() -> void:
	if backend == "google_play" and connected:
		_play.queryPurchases("inapp", false)


## Po przyznaniu nagrody: zużycie (produkty wielokrotne) albo potwierdzenie (jednorazowe).
func finish(product_id: String, token: String) -> void:
	if backend != "google_play" or token == "":
		return
	if bool(_consumable.get(product_id, true)):
		_play.consumePurchase(token)
	else:
		_play.acknowledgePurchase(token)


# --- Google Play -----------------------------------------------------------------

func _on_connected() -> void:
	connected = true
	_play.queryProductDetails(_product_ids, "inapp")
	_play.queryPurchases("inapp", false)
	ready_changed.emit(true)


func _on_disconnected() -> void:
	connected = false
	ready_changed.emit(false)
	# Ponowna próba połączenia po chwili (np. po powrocie sieci).
	get_tree().create_timer(15.0).timeout.connect(func():
		if not connected and _play:
			_play.startConnection())


func _on_connect_error(code: int, msg: String) -> void:
	connected = false
	push_warning("Billing: connect_error %d %s" % [code, msg])
	ready_changed.emit(false)


func _on_query_product_details_response(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != OK:
		return
	for d in res.get("product_details", []):
		var offers = d.get("one_time_purchase_offer_details_list", null)
		if offers is Array and not offers.is_empty():
			prices[str(d.product_id)] = str(offers[0].get("formatted_price", ""))
	prices_updated.emit()


func _on_query_purchases_response(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) == OK:
		for p in res.get("purchases", []):
			_handle_purchase(p)


func _on_on_purchase_updated(res: Dictionary) -> void:
	var code := int(res.get("response_code", -1))
	if code == OK:
		for p in res.get("purchases", []):
			_handle_purchase(p)
	elif code != USER_CANCELED:
		purchase_failed.emit("", _reason(code, str(res.get("debug_message", ""))))


func _handle_purchase(p: Dictionary) -> void:
	var state := int(p.get("purchase_state", 0))
	var token := str(p.get("purchase_token", ""))
	for pid in p.get("product_ids", []):
		if state == PURCHASED:
			# Jednorazowe już potwierdzone = przywrócenie (bez ponownego potwierdzania).
			purchase_ok.emit(str(pid), token)
		elif state == PENDING and not _pending.has(token):
			_pending[token] = true
			purchase_failed.emit(str(pid), "Płatność oczekuje na potwierdzenie w Google Play – nagroda pojawi się po jej zaksięgowaniu.")


func _on_consume_purchase_response(_res: Dictionary) -> void:
	pass


func _on_acknowledge_purchase_response(_res: Dictionary) -> void:
	pass


static func _reason(code: int, msg: String) -> String:
	match code:
		USER_CANCELED:
			return "Anulowano."
		2, 12, -1, -3:
			return "Brak połączenia z Google Play. Spróbuj ponownie."
		3:
			return "Płatności są niedostępne na tym urządzeniu lub koncie."
		4:
			return "Produkt jest chwilowo niedostępny."
		ITEM_ALREADY_OWNED:
			return "Ten produkt już posiadasz – użyj „Przywróć zakupy”."
	return "Nie udało się dokończyć zakupu (%d). %s" % [code, msg]
