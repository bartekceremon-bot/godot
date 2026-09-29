extends Node
## Połączenie z serwerem gry (WebSocket + JSON).
## Każda wiadomość to słownik z polem "t" (typ). Odebrane wiadomości są
## emitowane sygnałem `message`.

signal connected
signal disconnected(reason: String)
signal message(msg: Dictionary)

var _ws: WebSocketPeer = null
## Tryb offline (wersja Web): serwer gry działa w tej samej karcie przeglądarki
## (window.PK z pakietu server/dist-web/pk_offline.js), zamiast WebSocketa.
var _js = null
var _js_open := false
var _was_open := false
var _ping_timer := 0.0
## Ostatnio zmierzony ping w ms (do wyświetlenia w HUD).
var latency_ms := 0


## Czy w tej wersji dostępny jest serwer offline (gra w przeglądarce).
func offline_available() -> bool:
	return OS.has_feature("web") and JavaScriptBridge.get_interface("PK") != null


func connect_to(url: String) -> Error:
	close()
	if url == "offline":
		if not offline_available():
			return ERR_UNAVAILABLE
		_js = JavaScriptBridge.get_interface("PK")
		_js.connect()
		_js_open = true
		connected.emit.call_deferred()
		return OK
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_was_open = false
	return _ws.connect_to_url(url)


func close() -> void:
	if _js:
		_js.close()
		_js = null
		_js_open = false
	if _ws:
		_ws.close()
	_ws = null
	_was_open = false


func is_open() -> bool:
	return _js_open or (_ws != null and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN)


func send(msg: Dictionary) -> void:
	if _js_open:
		_js.send(JSON.stringify(msg))
		return
	if is_open():
		_ws.send_text(JSON.stringify(msg))


func _process(delta: float) -> void:
	if _js_open:
		var text = _js.poll()
		if text is String and not text.is_empty():
			var list = JSON.parse_string(text)
			if list is Array:
				for data in list:
					# Obsługa wiadomości może zamknąć połączenie (wylogowanie).
					if not _js_open:
						break
					if data is Dictionary:
						message.emit(data)
		return
	if _ws == null:
		return
	var ws := _ws
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _was_open:
			_was_open = true
			connected.emit()
		# Obsługa wiadomości może zamknąć połączenie (np. błąd logowania) – wtedy przerywamy.
		while _ws == ws and ws.get_available_packet_count() > 0:
			var text := ws.get_packet().get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data is Dictionary:
				if data.get("t") == "pong":
					latency_ms = int(Time.get_ticks_msec() - float(data.get("ts", 0)))
				else:
					message.emit(data)
		if _ws != ws:
			return
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			_ping_timer = 5.0
			send({"t": "ping", "ts": Time.get_ticks_msec()})
	elif state == WebSocketPeer.STATE_CLOSED:
		var reason := "Połączenie zamknięte."
		if not _was_open:
			reason = "Nie można połączyć się z serwerem."
		elif _ws.get_close_reason() == "relog":
			reason = "Zalogowano na tę postać z innego urządzenia."
		_ws = null
		_was_open = false
		disconnected.emit(reason)
