class_name SmartTranslation
extends Translation
## Tłumaczenie gry z polskiego na inny język.
## Teksty w grze są składane w kodzie (format "%s"), więc poza dokładnym
## słownikiem rozpoznajemy też gotowe napisy po wzorcach, np. "PZ: 120 / 300"
## pasuje do "PZ: %s / %s" → "HP: 120 / 300". Części %s tłumaczymy rekurencyjnie.

const SPLITS := ["\n", "  •  ", "   ", " • ", " – ", " — ", ", ", ": ", "  "]
const MAX_CACHE := 20000

var _exact := {}
var _cache := {}
## pierwszy znak dosłownego początku wzorca → lista wzorców
var _buckets := {}
## wzorce zaczynające się od zmiennej (sprawdzane zawsze)
var _loose: Array = []
## klucze kończące się ": " lub " " – tłumaczone jako przedrostek reszty
var _prefixes: Array = []

var _ph := RegEx.create_from_string("%(%|\\+?0?\\d*(?:\\.\\d+)?[sdf])")
var _tier := RegEx.create_from_string(" \\(T\\d+\\)$| [IVX]+$")
## ozdobniki i liczby na początku ("• ", "▶ ", "🔒 ", "+875K ", "0.8 ")
var _lead := RegEx.create_from_string("^((?:[•▶🔒★☆✔✖⚔❄\\-–—+×]+ ?)|(?:[+\\-]?\\d[\\d.,]*[KMBTQaiSxpOcDn]{0,2}%?×? ))(.+)$")
## wielkie litery: "KULA OGNIA" → "FIREBALL"
var _upper := {}
var _sentence := RegEx.create_from_string("(?<=[a-ząćęłńóśźż]{3}[.!?…]) (?=[A-ZĄĆĘŁŃÓŚŹŻ„])")
var _letters := RegEx.create_from_string("[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]")
## tryb testowy: zbiera teksty, których nie udało się przetłumaczyć
var log_missing := false
var missing := {}


func load_json(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("SmartTranslation: brak pliku %s" % path)
		return false
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		push_warning("SmartTranslation: zły format %s" % path)
		return false
	for k in data:
		add_entry(str(k), str(data[k]))
		# wzorce z odstępami na brzegach ("  •  ×2 na poz. %d") także bez nich – po podziale na części
		var sk := str(k).strip_edges().trim_prefix("•").strip_edges()
		if sk != str(k) and sk.find("%") >= 0 and not data.has(sk):
			add_entry(sk, str(data[k]).strip_edges().trim_prefix("•").strip_edges())
	# klucze z odstępem na końcu ("…walki. ") dostępne też bez niego
	for k in _exact.keys():
		var sk := str(k).strip_edges().trim_prefix("•").strip_edges()
		if sk != k and not sk.is_empty() and not _exact.has(sk):
			_exact[sk] = str(_exact[k]).strip_edges()
	for k in _exact:
		var u := str(k).to_upper()
		if u != k and not _upper.has(u):
			_upper[u] = str(_exact[k]).to_upper()
	_prefixes.sort_custom(func(a, b): return a.length() > b.length())
	return true


func add_entry(key: String, value: String) -> void:
	if key.find("%") < 0:
		_exact[key] = value
		if key.length() > 3 and (key.ends_with(": ") or key.ends_with("! ")):
			_prefixes.append(key)
		return
	var lits := _ph.search_all(key)
	# sam wzorzec też dokładnie – tr("Rezerwa: %d%%") % x tłumaczy przed wstawieniem liczb
	_exact[key] = value
	if lits.is_empty():
		return
	# wzorce strukturalne ("%s  ×%d", "%d× %s") – tylko gdy przetłumaczy się któraś część %s;
	# same "%s %s" pomijamy, bo cięłyby dowolne zdania na słowa
	var literal := _ph.sub(key, "", true)
	var structural := not _letters.search(literal)
	if structural and (key.find("%s") < 0 or (literal.strip_edges().is_empty() and not _has_number_ph(lits))):
		return
	var pattern := "^"
	var kinds: Array = []
	var pos := 0
	for m in lits:
		pattern += _escape(key.substr(pos, m.get_start() - pos))
		var spec := m.get_string(1)
		if spec == "%":
			pattern += "%"
		elif spec.ends_with("s"):
			pattern += "(.*?)"
			kinds.append("s")
		elif spec.ends_with("f"):
			pattern += "(-?\\d+(?:[.,]\\d+)?)"
			kinds.append("n")
		else:
			pattern += "([+-]?\\d+)"
			kinds.append("n")
		pos = m.get_end()
	pattern += _escape(key.substr(pos)) + "$"
	var re := RegEx.create_from_string(pattern)
	if not re.is_valid():
		return
	var entry := {"re": re, "kinds": kinds, "out": _split_value(value), "score": 0 if structural else literal.length(), "structural": structural}
	var head := key.substr(0, lits[0].get_start())
	if head.is_empty():
		_loose.append(entry)
	else:
		var b: Array = _buckets.get(head[0], [])
		b.append(entry)
		_buckets[head[0]] = b


## Tekst wyjściowy pocięty na kawałki dosłowne i miejsca na zmienne.
func _has_number_ph(lits: Array) -> bool:
	for m in lits:
		var spec: String = m.get_string(1)
		if spec != "%" and not spec.ends_with("s"):
			return true
	return false


func _split_value(value: String) -> Array:
	var parts: Array = []
	var pos := 0
	for m in _ph.search_all(value):
		var spec := m.get_string(1)
		var lit := value.substr(pos, m.get_start() - pos)
		if spec == "%":
			parts.append(lit + "%")
		else:
			parts.append(lit)
			parts.append(null)
		pos = m.get_end()
	parts.append(value.substr(pos))
	return parts


func _escape(s: String) -> String:
	var out := ""
	for c in s:
		if "\\^$.|?*+()[]{}".find(c) >= 0:
			out += "\\"
		out += c
	return out


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if s.is_empty():
		return &""
	var r = translate(s)
	if r == null:
		if log_missing and _letters.search(s):
			missing[s] = true
		return &""
	return StringName(r)


## Zwraca przetłumaczony tekst albo null, gdy nic się nie dało przetłumaczyć.
func translate(s: String, depth: int = 0):
	if _cache.has(s):
		return _cache[s]
	var r = _translate(s, depth)
	if _cache.size() > MAX_CACHE:
		_cache.clear()
	_cache[s] = r
	return r


func _translate(s: String, depth: int):
	if _exact.has(s):
		return _exact[s]
	if depth > 6 or s.length() < 2 or not _letters.search(s):
		return null
	if _upper.has(s):
		return _upper[s]
	# białe znaki na brzegach
	var core := s.strip_edges()
	if core != s and not core.is_empty():
		var rc = translate(core, depth + 1)
		if rc != null:
			var a := s.find(core)
			return s.substr(0, a) + rc + s.substr(a + core.length())
	# przyrostek poziomu "(T3)" albo stopnia "II"
	if true:
		var m := _tier.search(s)
		if m:
			var rt = translate(s.substr(0, m.get_start()), depth + 1)
			if rt != null:
				return rt + m.get_string()
	var rw = _by_template(s, depth, false)
	if rw != null:
		return rw
	var ml := _lead.search(s)
	if ml:
		var rl = translate(ml.get_string(2), depth + 1)
		if rl != null:
			return ml.get_string(1) + rl
	# zdania sklejone w kodzie: "Zdanie pierwsze. Zdanie drugie."
	if s.find("\n") < 0:
		var cuts := _sentence.search_all(s)
		if not cuts.is_empty():
			var out := ""
			var pos := 0
			var anys := false
			for i in cuts.size() + 1:
				var end := cuts[i].get_start() if i < cuts.size() else s.length()
				var sx := s.substr(pos, end - pos)
				var rs = translate(sx, depth + 1)
				if rs != null:
					anys = true
					sx = rs
				out += sx + (" " if i < cuts.size() else "")
				pos = end + 1
			if anys:
				return out
	for sep in SPLITS:
		if s.find(sep) < 0:
			continue
		var parts := s.split(sep)
		var any := false
		for i in parts.size():
			var rp = translate(parts[i], depth + 1)
			if rp != null:
				parts[i] = rp
				any = true
		if any:
			return sep.join(parts)
	# wzorce strukturalne dopiero po podziale – inaczej "%s (%s)" łapałby całe zdania
	var rst = _by_template(s, depth, true)
	if rst != null:
		return rst
	for p in _prefixes:
		if s.begins_with(p) and s.length() > p.length():
			var rest = translate(s.substr(p.length()), depth + 1)
			return _exact[p] + (s.substr(p.length()) if rest == null else rest)
	return null


func _by_template(s: String, depth: int, structural: bool):
	var best = null
	var best_score := -1
	var cands: Array = _buckets.get(s[0], [])
	for list in [cands, _loose]:
		for e in list:
			if e.score <= best_score or e.structural != structural:
				continue
			var m: RegExMatch = e.re.search(s)
			if m == null:
				continue
			var vals: Array = []
			var hit := false
			for i in e.kinds.size():
				var g := m.get_string(i + 1)
				if e.kinds[i] == "s":
					var rg = translate(g, depth + 1)
					hit = hit or rg != null
					vals.append(g if rg == null else rg)
				else:
					vals.append(g)
			if e.structural and not hit:
				continue
			var out := ""
			var vi := 0
			for part in e.out:
				if part == null:
					out += str(vals[vi]) if vi < vals.size() else ""
					vi += 1
				else:
					out += part
			best = out
			best_score = e.score
	return best


# --- wybór języka -----------------------------------------------------------

## Języki gry: [kod, nazwa własna]. Polski to język źródłowy (bez słownika).
const LANGUAGES := [["pl", "Polski"], ["en", "English"], ["es", "Español"], ["pt", "Português"], ["de", "Deutsch"]]

## Bieżące tłumaczenie (null po polsku).
static var _installed: SmartTranslation = null
static var _log := false


static func available(code: String) -> bool:
	return code == "pl" or FileAccess.file_exists("res://data/i18n/%s.json" % code)


## Rejestruje tłumaczenie wybranego języka i ustawia go ("auto", "pl", "en", "es", "pt", "de").
static func apply_language(lang: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			lang = a.substr(7)
			_log = true
	var loc := resolve(lang)
	# Po polsku tłumaczenia nie rejestrujemy – Godot użyłby go jako zapasowego (fallback „en”).
	if _installed != null and (loc == "pl" or _installed.locale != loc):
		TranslationServer.remove_translation(_installed)
		_installed = null
	if loc != "pl" and _installed == null:
		_installed = SmartTranslation.new()
		_installed.locale = loc
		_installed.log_missing = _log
		_installed.load_json("res://data/i18n/%s.json" % loc)
		TranslationServer.add_translation(_installed)
	TranslationServer.set_locale(loc)
	return loc


static func resolve(lang: String) -> String:
	for l in LANGUAGES:
		if lang == l[0] and available(lang):
			return lang
	var sys := OS.get_locale_language()
	if sys == "pl":
		return "pl"
	if sys in ["es", "pt", "de"] and available(sys):
		return sys
	return "en"


## Tłumaczenie poza węzłami (np. powiadomienia) – zwraca oryginał po polsku.
static func t(s: String) -> String:
	if _installed == null:
		return s
	var r = _installed.translate(s)
	return s if r == null else r


## Zapis brakujących tłumaczeń (tryb testowy, --lang=xx).
static func dump_missing(path: String) -> void:
	if _installed == null or _installed.missing.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		for k in _installed.missing:
			f.store_line(str(k).c_escape())


## Wyrejestrowanie przed zamknięciem (skrypt nie może przeżyć silnika GDScript).
static func uninstall() -> void:
	if _installed != null:
		TranslationServer.remove_translation(_installed)
		_installed = null
