# Raport testów — AI Bliżej: Strażnicy Iskry 1.0.0

Data: 24.10.2026. Wszystkie wyniki poniżej pochodzą z faktycznie uruchomionych testów. Czego nie sprawdzono — wypisano na końcu.

## Środowisko testowe

| | |
|---|---|
| Maszyna | kontener Linux x86_64, 4 wirtualne rdzenie, 15 GB RAM, **bez GPU** |
| Silnik | Godot 4.7.2.stable.official (ed1daf0bf), tryb headless + szablony Web 4.7.2 |
| Przeglądarka | Chromium 153.0.8010.12 (Playwright), WebGL 2.0 przez **SwiftShader** (rasteryzacja programowa na CPU) |
| Serwer | `python3 -m http.server`, gra serwowana z podkatalogu **`/gra/`** (jak docelowo na aiblizej.pl) |
| Build | eksport Web jednowątkowy (`web_nothreads`), produkcyjny `dist/` oraz testowy (preset „Web (testy)”, debug + katalog `tests/`) |

## 1. Testy automatyczne (headless, natywnie)

| Test | Polecenie | Wynik |
|---|---|---|
| Kompilacja wszystkich skryptów + spójność danych (stacje zadań, portale, punkty odrodzenia, dialogi, przedmioty) | `tests/check_all.gd` | **OK** |
| Zapis: zapis/odczyt, kopia zapasowa, oba pliki uszkodzone, walidacja niezaufanych danych (zła wersja, klasa, typy, nieznane przedmioty i zadania, NaN), eksport/import, śmieci, za duży tekst | `tests/save_test.gd` | **24/24** |
| Pełne przejście gry **każdą z 4 klas** (patrz niżej) | `tests/autotest_scene.tscn` | **661/0** |

Pełne przejście obejmuje dla każdej klasy: rozmowę z Lumi, samouczek walki (prawdziwy atak klasy rani przeciwnika, umiejętność zużywa energię i ma odnowienie), wszystkie **12 zadań**. Dla każdego zadania test sprawdza: czy błędna odpowiedź jest odrzucana **z wyjaśnieniem i bez utraty zdrowia**, czy zadanie da się rozwiązać i czy jest zaliczane. Dalej: zmiany świata (most, kładka, skrzynie, brama, iluzja, kładki Archiwum), podróże między obszarami, **osiągalność** każdej stacji, NPC, portalu i ołtarza (przeszukiwanie siatki z prawdziwymi kolizjami) oraz to, że obszary są **zablokowane przed rozwiązaniem** zadania. Do tego walka z Mirażem: 2 fazy iluzji, każda kopia różni się od prawdziwego, atak obszarowy nie demaskuje iluzji, pomyłka nie kończy fazy, trafienie prawdziwego kończy. Na końcu: fragmenty, finał, **poziom 5**, eksploracja po zakończeniu, zmiana klasy bez utraty postępu, a także śmierć i odrodzenie przy Kamieniu Iskry z pełnym zdrowiem i zachowanym postępem.

## 2. Testy wyeksportowanej gry w przeglądarce

| Test | Wynik |
|---|---|
| Pełne przejście gry **w przeglądarce** (eksport Web, `?autotest=1`, Chromium + SwiftShader, z podkatalogu) | Tkacz 172/0 (3 przebiegi), Mechanik 171/0, Tropiciel 171/0, Strażnik 171/0 i 172/0 (2 przebiegi; drugi z dodatkową asercją iluzji). Jeden wcześniejszy przebieg Tkacza dał 170/1 przez wyścig w samym teście (opóźnione intro przy wolnych klatkach) — test poprawiono, kolejne przebiegi bez błędów. |
| Ładowanie produkcyjnego `dist/` z `/gra/` | wszystkie pliki **200**, `index.wasm` → `application/wasm`, **0 nieudanych żądań, 0 błędów i ostrzeżeń w konsoli**; gotowość po 2,4 s (lokalny serwer, bez sieci) |
| Sprawdzenie WebGL 2.0 i komunikat o braku obsługi | logika w `web/shell.html` (sprawdzane `Engine.getMissingFeatures` + kontekst `webgl2`); komunikatu o braku nie wywołano na żywo — Chromium wspiera WebGL 2 |
| **Zapis po przeładowaniu** (produkcja): nowa gra Mechanikiem → odświeżenie → „Graj dalej” → Mechanik, poz. 1 | **działa**; plik `save.json` widoczny w IndexedDB (`/userfs/...`) |
| **Uszkodzony zapis** (nadpisanie danych w IndexedDB) | ekran tytułowy: „Zapis był uszkodzony i nie dał się odczytać. Możesz zacząć nową grę.” — gra działa dalej |
| Ekrany (zrzuty): tytuł, scenki, wybór klasy, świat, wszystkie typy zadań (stan początkowy, błąd, sukces), menu (dziennik, ekwipunek, mapa, postać, ustawienia, zapis), ołtarz klas, 4 obszary, boss i faza iluzji, finał | wykonane; znalezione problemy poprawiono (lista niżej) |
| Emulacja telefonu 844×390 (dotyk, `isMobile`): **jednoczesny ruch joystickiem i atak** dwoma palcami (CDP `dispatchTouchEvent`) | **PASS** — gracz przesunął się o ok. 670 px, atak aktywny w tym samym czasie |
| Pion 390×844 i mały ekran 360×640, zmiana rozmiaru w trakcie gry | układ się przelicza, HUD i przyciski czytelne (zrzuty) |
| Utrata fokusu (zdarzenie `blur`) | **gra pauzuje** (menu pauzy), przyciski zwolnione |

## 3. Wydajność (pomiary)

| Pomiar | Środowisko | Wynik |
|---|---|---|
| FPS, 1280×720, jakość wysoka | Chromium + **SwiftShader** (bez GPU), 4 vCPU | 4–6 FPS |
| FPS, 1280×720, jakość niska | j.w. | ok. 6 FPS |
| FPS, 844×390 (rozmiar telefonu), jakość wysoka | j.w. | 8–13 FPS |

**Interpretacja:** profil CPU (CDP) pokazuje, że ok. 91% czasu wątku głównego to oczekiwanie w `blitOffscreenFramebuffer ← emscripten_webgl_do_commit_frame`, czyli prezentacja klatki czekająca na programową rasteryzację SwiftShadera. Te liczby **nie są** pomiarem wydajności na prawdziwym GPU. Celu „60 FPS na typowym komputerze” i „grywalnie na telefonie średniej klasy” **nie zmierzono**, bo nie było dostępu do sprzętu z GPU.

**Optymalizacja wykonana na podstawie profilu:** pierwotnie gra co klatkę przerysowywała dziesiątki obiektów (stacje, portale, NPC, rekwizyty, chmury). W Godot 4 Compatibility na WebGL każde takie przerysowanie tworzy nowe bufory i VAO. Przebudowano to na statyczne rysunki animowane transformacjami i modulacją węzłów. Przerysowanie zostało tylko dla postaci w kadrze, a efekty ambientowe odświeżają się ok. 12 razy na sekundę i tylko na ekranie. Praca wątku głównego poza oczekiwaniem na rasteryzację spadła z ok. 32 do ok. 15 ms/klatkę w tym samym środowisku. Wywołania tworzenia VAO i buforów spadły z ok. 1% do ok. 0,3% próbek.

Tryb niski ogranicza: liczbę cząsteczek (36 → 14), trawę (~40%), mgłę, chmury. Tryb ograniczonych animacji wyłącza promień latarni, kołysanie, drgania kamery i skraca przejścia.

## 4. Znalezione i poprawione problemy

Testy w przeglądarce:
- Tło i ilustracje miały zerowy rozmiar (`set_anchors_preset` bez offsetów) → `set_anchors_and_offsets_preset`.
- Przyciski z zawijaniem tekstu w `HFlowContainer` zapadały się do zerowej szerokości (zadania) → listy na pełną szerokość.
- Okno BLIKA rosło do 3000 px (kontener nie kurczy się po zmianie tekstu) → dopasowanie wysokości co klatkę.
- Brak glifów „→” i „█” w czcionce → zamienione na tekst.
- **Dotyk: joystick nie działał**, bo zgodnościowe zdarzenia myszy wysyłane przez przeglądarkę po dotyku przełączały grę w tryb myszy → ignorowanie ich przez 1,5 s po dotyku.
- Interfejs na telefonie był za mały (skala 0,54) → bazowa rozdzielczość dopasowana do rozmiaru ekranu w pikselach CSS (tekst ≥ ~80%).
- Pasek bossa i okno BLIKA zasłaniały kopie Miraża → pasek na dole, kopie i boss w środkowym pasie sali, kamera obejmuje bossa.
- Komunikaty zasłaniały postać → przeniesione niżej. Intro BLIKA powtarzało się po wczytaniu → zapis flagi.

Przegląd kodu (`/code-review`):
- Podwójne otwarcie skrzyni lub miejsca klasowego dawało podwójną nagrodę.
- Ataki obszarowe, łańcuchowe i konstrukcje rozstrzygały zagadkę iluzji za gracza.
- `validate()` i `Settings.from_dict()` mogły rzucić błąd skryptu przy złych typach z importu.
- Test zapisu kasował prawdziwy zapis.
- Dryf panelu przy wielokrotnym „Sprawdź”, brak domyślnych kategorii w `sort`, niekończące się odpytywanie po anulowaniu wyboru pliku.

Wszystkie poprawiono. `dist/` pozostaje w repozytorium celowo (wymóg dostarczenia eksportu).

## 5. Czas gry

Nie było testów z ludźmi, więc **30–45 minut to szacunek, nie pomiar.** Składniki:
- przejście tras między celami: ok. 2 min (pomiar z danych map przy prędkości gracza),
- teksty do przeczytania (dialogi, cele, wyjaśnienia zadań, odniesienia do życia): ok. 3–4 tys. słów, czyli ok. 15–25 min dla ucznia,
- 12 zadań (interakcja, próby, podpowiedzi): ok. 10–20 min,
- walka z 31 przeciwnikami i bossem w 2 fazach iluzji: ok. 5–8 min,
- skrzynie, sekrety, tablice wiedzy, scenki: ok. 3–5 min.

Szybki gracz pomijający teksty może skończyć w ok. 20 minut. Warto zmierzyć to na kilku osobach z grupy docelowej.

## 6. Czego NIE sprawdzono

- **Fizyczne urządzenia**: żaden telefon ani tablet. Testy dotyku to emulacja Chromium, a nie test na urządzeniu.
- **Safari / iPhone / iPad** — nie testowano (WebKit w ogóle nie był uruchamiany).
- **Firefox**, **Edge**, Chrome na Androidzie — nie testowano.
- Wydajność na **prawdziwym GPU** (komputer, telefon średniej klasy) — nie mierzono.
- Hosting **home.pl**: typ MIME, `.htaccess`, kompresja — nie sprawdzano (brak dostępu). Lokalny serwer podaje poprawny MIME.
- Wolne łącze i czas pobierania ok. 41 MB (ok. 11 MB po gzip) — nie mierzono.
- Słyszalny dźwięk (środowisko testowe bez audio): sprawdzono generowanie plików, kolejkę odtwarzania i to, że muzyka startuje dopiero po „Graj”. Brzmienia nie odsłuchano.
- Import zapisu przez okno wyboru pliku i `window.prompt` na prawdziwych przeglądarkach mobilnych. Logika importu i walidacji jest przetestowana headless.
- Pad, czytniki ekranu, długie sesje (wycieki pamięci) — nie testowano.
- Komunikat o braku WebGL 2 — kod jest, ale na przeglądarce bez WebGL 2 go nie wywoływano.
