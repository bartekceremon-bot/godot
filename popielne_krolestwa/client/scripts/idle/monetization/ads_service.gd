class_name AdsService
extends Node
## Reklamy z nagrodą – wyłącznie dobrowolne (gracz sam wybiera „Obejrzyj reklamę”), bez reklam
## wyskakujących i banerów. Na Androidzie: wtyczka godot-admob (węzeł klasy „Admob”, dodawana
## w CI razem z identyfikatorem aplikacji AdMob) z formularzem zgody UMP (RODO / EOG) przed
## pierwszym wyświetleniem. Poza Androidem – tryb testowy z atrapą reklamy.
##
## show_rewarded(on_reward: Callable) – wywołuje on_reward tylko po obejrzeniu do końca.

signal state_changed

## "admob" | "sandbox" | "none"
var backend := "none"
var _admob: Node
var _loaded := false
var _loading := false
var _reward_cb: Callable
var _earned := false
var _overlay_host: Control


func setup(overlay_host: Control, allow_sandbox: bool, rewarded_unit_id: String) -> void:
	_overlay_host = overlay_host
	var path := _admob_script()
	if OS.get_name() == "Android" and path != "":
		backend = "admob"
		_admob = (load(path) as Script).new()
		# Identyfikatory: prawdziwe w buildzie release (CI wpisuje je do android_export.cfg i tutaj).
		_admob.set("is_real", not OS.is_debug_build() and rewarded_unit_id != "")
		if rewarded_unit_id != "":
			_admob.set("android_real_rewarded_id", rewarded_unit_id)
		add_child(_admob)
		for sig in ["initialization_completed", "rewarded_ad_loaded", "rewarded_ad_failed_to_load", "rewarded_ad_user_earned_reward",
				"rewarded_ad_dismissed_full_screen_content", "rewarded_ad_failed_to_show_full_screen_content",
				"consent_info_updated", "consent_info_update_failed", "consent_form_loaded", "consent_form_dismissed", "consent_form_failed_to_load"]:
			if _admob.has_signal(sig):
				_admob.connect(sig, Callable(self, "_on_" + sig))
		# Najpierw zgoda (UMP), potem inicjalizacja SDK.
		if _admob.has_method("update_consent_info"):
			_admob.call("update_consent_info")
		else:
			_admob.call("initialize")
	elif allow_sandbox:
		backend = "sandbox"
		_loaded = true


## Ścieżka skryptu klasy „Admob” z wtyczki (jeśli jest w projekcie).
static func _admob_script() -> String:
	for c in ProjectSettings.get_global_class_list():
		if str(c.get("class", "")) == "Admob":
			return str(c.get("path", ""))
	return ""


func available() -> bool:
	return backend != "none"


func ready_to_show() -> bool:
	return backend == "sandbox" or (backend == "admob" and _loaded)


func show_rewarded(on_reward: Callable) -> bool:
	if not ready_to_show():
		if backend == "admob" and not _loading:
			_load()
		return false
	_reward_cb = on_reward
	_earned = false
	if backend == "sandbox":
		_sandbox_ad()
		return true
	_loaded = false
	_admob.call("show_rewarded_ad")
	return true


## Formularz prywatności (Ustawienia → „Zgoda na reklamy”) – wymagane, by gracz mógł zmienić decyzję.
func show_privacy_options() -> void:
	if backend == "admob" and _admob.has_method("load_consent_form"):
		_admob.call("load_consent_form")


func _load() -> void:
	if backend == "admob" and _admob:
		_loading = true
		_admob.call("load_rewarded_ad")


# --- AdMob --------------------------------------------------------------------------

func _on_consent_info_updated() -> void:
	# Formularz pokazuje się tylko tam, gdzie jest wymagany (EOG, UK); potem inicjalizacja.
	if _admob.has_method("load_consent_form"):
		_admob.call("load_consent_form")
	_admob.call("initialize")


func _on_consent_info_update_failed(_e = null) -> void:
	_admob.call("initialize")


func _on_consent_form_loaded() -> void:
	var st = _admob.call("get_consent_status") if _admob.has_method("get_consent_status") else null
	if st == null or str(st).to_upper().contains("REQUIRED"):
		_admob.call("show_consent_form")


func _on_consent_form_dismissed(_e = null) -> void:
	_load()


func _on_consent_form_failed_to_load(_e = null) -> void:
	pass


func _on_initialization_completed(_s = null) -> void:
	_load()


func _on_rewarded_ad_loaded(_a = null, _b = null) -> void:
	_loaded = true
	_loading = false
	state_changed.emit()


func _on_rewarded_ad_failed_to_load(_a = null, _b = null) -> void:
	_loading = false
	get_tree().create_timer(30.0).timeout.connect(_load)


func _on_rewarded_ad_user_earned_reward(_a = null, _b = null) -> void:
	_earned = true


func _on_rewarded_ad_dismissed_full_screen_content(_a = null) -> void:
	if _earned and _reward_cb.is_valid():
		_reward_cb.call()
	_earned = false
	_load()


func _on_rewarded_ad_failed_to_show_full_screen_content(_a = null, _b = null) -> void:
	_load()


# --- Tryb testowy ----------------------------------------------------------------------

## Atrapa reklamy (3 s, z wyraźnym napisem) – tylko poza Google Play.
func _sandbox_ad() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.92)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.z_index = 50
	var l := IdleUI.hud_label("REKLAMA TESTOWA\n(w wersji z Google Play – prawdziwa reklama)\n\n3", 30, Color(1, 0.85, 0.5), 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dim.add_child(l)
	_overlay_host.add_child(dim)
	var tw := dim.create_tween()
	for i in [2, 1]:
		tw.tween_interval(1.0)
		tw.tween_callback(func(): l.text = "REKLAMA TESTOWA\n(w wersji z Google Play – prawdziwa reklama)\n\n%d" % i)
	tw.tween_interval(1.0)
	tw.tween_callback(func():
		dim.queue_free()
		if _reward_cb.is_valid():
			_reward_cb.call())
