class_name MailManager
extends RefCounted
## Poczta: wiadomości od Gildii (powitanie, nowości kolejnych wersji). Prezent dołączony do
## powitania i do wiadomości o bieżącej wersji – odbierany raz.
## Stan: s.mail = {read: [id], claimed: [id]}.

## [id, tytuł, treść, prezent {gems, chest} albo {}]
const MESSAGES := [
	["v3.9", "Nowości: wersja 3.9", "Gra mówi teraz także po hiszpańsku, portugalsku i niemiecku – zmień język w Ustawieniach. Powiedz znajomym z innych krajów! W prezencie od Gildii – 50 żarokryształów.", {"gems": 50}],
	["v3.7", "Nowości: wersja 3.7", "Wyzwania tygodnia: 7 celów co tydzień i wielka nagroda za komplet (Menu → Wyzwania tygodnia). Poczta – tutaj zawsze przeczytasz, co nowego w grze. W prezencie od Gildii – 100 żarokryształów i Rzadka skrzynia!", {"gems": 100, "chest": 3}],
	["v3.6", "Nowości: wersja 3.6", "Sen Popielnika – tryb roguelike od etapu 40. Schodź coraz głębiej, wybieraj błogosławieństwa i zbieraj Okruchy Snu na Drzewo Snu.", {}],
	["v3.5", "Nowości: wersja 3.5", "Festyn Żaru w dniach 1–10 każdego miesiąca – lampiony, kram i strój Mistrz Festynu. Przebudzenie najemników: gwiazdki potrajające DPS.", {}],
	["v3.4", "Nowości: wersja 3.4", "Klasy bohatera z umiejętnościami ostatecznymi, zaklęcia ekwipunku, kod zapisu do przenoszenia gry i wibracje.", {}],
	["v3.3", "Nowości: wersja 3.3", "Ścieżka Popielnika dla nowych graczy, Koło Żaru z darmowym obrotem codziennie, nowe wydarzenia i osiągnięcia.", {}],
	["v3.2", "Nowości: wersja 3.2", "Lochy Żaru, Arena Popiołu z ligami i Relikwie w zestawach.", {}],
	["welcome", "Witaj, Popielniku!", "Gildia Popielgrodu wita nowego bohatera. Klikaj ATAK!, wynajmuj najemników i podążaj Ścieżką Popielnika – karta celu na ekranie walki podpowie, co dalej. Na dobry początek: 50 żarokryształów.", {"gems": 50}],
]

var gm: IdleGame


func _init(g: IdleGame) -> void:
	gm = g


func _st() -> Dictionary:
	if not gm.s.has("mail"):
		gm.s["mail"] = {"read": [], "claimed": []}
	return gm.s.mail


func is_read(id: String) -> bool:
	return (_st().read as Array).has(id)


func has_gift(i: int) -> bool:
	var m: Array = MESSAGES[i]
	return not (m[3] as Dictionary).is_empty() and not (_st().claimed as Array).has(str(m[0]))


func unread() -> int:
	var n := 0
	for i in MESSAGES.size():
		if not is_read(str(MESSAGES[i][0])) or has_gift(i):
			n += 1
	return n


func mark_read(i: int) -> void:
	var id := str(MESSAGES[i][0])
	if not is_read(id):
		_st().read.append(id)
		gm.changed.emit("mail")


func claim(i: int) -> Array:
	if not has_gift(i):
		return []
	var m: Array = MESSAGES[i]
	_st().claimed.append(str(m[0]))
	mark_read(i)
	var got: Array = []
	var r: Dictionary = m[3]
	if r.has("gems"):
		gm.add_gems(int(r.gems))
		got.append(["gems", int(r.gems)])
	if r.has("chest"):
		gm.inventory.add("chest_%d" % int(r.chest), 1)
		got.append(["chest_%d" % int(r.chest), 1])
	gm.changed.emit("mail")
	return got
