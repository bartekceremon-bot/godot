# AI Bliżej: Strażnicy Iskry

Edukacyjna przygoda action RPG dla jednej osoby, działająca w przeglądarce (komputer, telefon, tablet) bez instalacji. Gracz zostaje Strażnikiem Iskry w Luminarze — archipelagu unoszących się wysp — i odbudowuje Latarnię Wiedzy. Robi to przez eksplorację, walkę oraz rozwiązywanie praktycznych zadań o mądrym korzystaniu z AI, logice i bezpieczeństwie w sieci.

Docelowe miejsce publikacji: `https://aiblizej.pl/gra/` (gra **nie została** nigdzie opublikowana — wymaga to Twojej decyzji).

## Wersja silnika

| | |
|---|---|
| Silnik | **Godot 4.7.2.stable.official** (build `ed1daf0bf`) |
| Język | GDScript |
| Renderer | Compatibility (WebGL 2.0) |
| Eksport | Web, **jednowątkowy** (bez SharedArrayBuffer, bez nagłówków COOP/COEP), bez GDExtension |
| Szablony | oficjalne szablony eksportu 4.7.2.stable (`web_nothreads_release.zip`) |

## Co zawiera pierwsza wersja

- Animowany ekran tytułowy, scenka wprowadzająca, wybór jednej z **4 grywalnych klas** (Tkacz Słów, Mechanik Iskry, Tropiciel Prawdy, Strażnik Tarczy). Każda ma atak, 2 umiejętności, pasywkę, ścieżkę rozwoju do poziomu 5 i własne interakcje ze światem.
- Baza **Latarnia Wiedzy** z samouczkiem wplecionym w fabułę oraz 3 obszary: **Ogród Poleceń**, **Warsztat Zależności** i **Archiwum Echa** (z Salą Luster).
- **12 zadań edukacyjnych** w 6 typach interakcji: układanie kroków, składanie polecenia/reguły z części, sprawdzanie wyników automatu, uprawnienia, usuwanie danych prywatnych, phishing, porównywanie źródeł, silne hasło, fakty/opinie. Każde zadanie zmienia świat: buduje się most, otwiera portal, kwitną grządki, płynie woda, rusza przenośnik, znika iluzja, otwierają się bramy.
- **3 typy przeciwników** (Szumik, Zakłócacz, Mglisty Golem) z czytelnymi zapowiedziami ataków oraz **boss Miraż**. Jego iluzje demaskuje się wskazówkami z Kamieni Prawdy.
- Poziomy 1–5, ekwipunek, skrzynie, sekrety, Kamienie Iskry (punkty kontrolne), dziennik, animowana mapa z szybką podróżą, finał przywracający światło Latarni i dalsza eksploracja po zakończeniu.
- Zapis lokalny (wersjonowany, walidowany, z kopią zapasową), eksport i import zapisu.
- Sterowanie: klawiatura + mysz, dotyk (joystick, multitouch, wspomagane celowanie), pad (bonus).
- Ustawienia: głośność (ogólna/muzyka/efekty), jakość grafiki, ograniczone animacje, drgania kamery, wielkość tekstu, przyciski dotykowe.

## Struktura katalogów

```
straznicy-iskry/
├── godot/                  projekt Godot (project.godot, export_presets.cfg)
│   ├── data/               TREŚCI: klasy, zadania, dialogi, przedmioty, przeciwnicy, obszary (JSON)
│   ├── scripts/core/       autoloady: Data, Settings, GameState (zapis), Audio, Router
│   ├── scripts/world/      świat: obszar, wyspy, mosty, obiekty, interakcje, kontroler gry
│   ├── scripts/actors/     gracz, umiejętności, przeciwnicy, boss, BLIK, pociski
│   ├── scripts/puzzles/    silniki zadań (sequence, slots, marks, sort, compare, password)
│   ├── scripts/ui/         HUD, sterowanie dotykowe, dialogi, menu, mapa, ekrany
│   ├── scripts/fx/         grafika wektorowa (Art) i efekty
│   ├── assets/             czcionki (OFL), shadery, dźwięki i muzyka (wygenerowane)
│   ├── web/shell.html      własna strona ładująca (loader, komunikaty błędów, safe areas)
│   └── tests/              testy automatyczne (nie trafiają do eksportu produkcyjnego)
├── dist/                   gotowy eksport Web (zawartość do wgrania do /gra/)
├── wydanie/                archiwa ZIP: eksport i źródła
├── tools/                  build.sh, generate_audio.py, fix_inference.py
└── docs/                   architektura, licencje, raport testów, przykład .htaccess
```

## Uruchomienie lokalne

1. Zainstaluj **Godot 4.7.2** (wersja standardowa, nie .NET) ze strony <https://godotengine.org/download/archive/4.7.2-stable/>.
2. Otwórz `straznicy-iskry/godot/project.godot` w edytorze i naciśnij F5.

Wersję przeglądarkową uruchom **przez serwer HTTP** — nie otwieraj `index.html` bezpośrednio z dysku (`file://` nie działa):

```bash
cd straznicy-iskry/dist
python3 -m http.server 8000
# otwórz http://localhost:8000/
```

Żeby sprawdzić działanie z podkatalogu (jak na `aiblizej.pl/gra/`):

```bash
mkdir -p /tmp/www && ln -s "$PWD/straznicy-iskry/dist" /tmp/www/gra
cd /tmp/www && python3 -m http.server 8000
# otwórz http://localhost:8000/gra/
```

## Eksport

W edytorze: **Projekt → Eksportuj… → „Web” → Eksportuj projekt** (szablony eksportu 4.7.2 muszą być zainstalowane: Edytor → Zarządzaj szablonami eksportu).

Z wiersza poleceń (eksport + archiwa ZIP):

```bash
cd straznicy-iskry
./tools/build.sh            # wymaga polecenia `godot` w wersji 4.7.2 w PATH
```

Skrypt sprawdza dane i skrypty, eksportuje do `dist/` (dokłada przykładowy `.htaccess` z `docs/htaccess-przyklad.txt`) i tworzy:
- `wydanie/straznicy-iskry-gra-web.zip` — gotowa gra; `index.html` leży w głównym katalogu archiwum,
- `wydanie/straznicy-iskry-zrodla.zip` — źródła, narzędzia, dokumentacja.

Dźwięki i muzykę można wygenerować ponownie: `python3 tools/generate_audio.py` (Python 3 + numpy + ffmpeg z libvorbis).

## Wgranie na home.pl do katalogu /gra/

1. Rozpakuj `straznicy-iskry-gra-web.zip` na komputerze. Zobaczysz pliki `index.html`, `index.js`, `index.wasm`, `index.pck`, `index.audio.worklet.js`, `index.audio.position.worklet.js`, ikony PNG i `.htaccess` (plik ukryty — włącz pokazywanie ukrytych plików).
2. Zaloguj się do panelu home.pl i sprawdź, który katalog na serwerze jest przypisany do domeny **aiblizej.pl** (ustawienia domeny / katalog domeny). Nie zmieniaj w nim plików strony głównej.
3. Przez Menedżer plików w panelu lub klienta FTP/SFTP (np. FileZilla) utwórz w tym katalogu podkatalog **`gra`**.
4. Wgraj do `gra/` **wszystkie** rozpakowane pliki (bez dodatkowego folderu pośredniego). Nazwy plików muszą zostać bez zmian — `index.html` odwołuje się do `index.js`, `index.wasm` i `index.pck`.
5. Otwórz `https://aiblizej.pl/gra/` w przeglądarce. Jeśli zobaczysz ekran ładowania z paskiem postępu, a potem ekran tytułowy — gotowe.

### Wymagania hostingu i typ MIME

- Hosting statyczny przez **HTTPS** wystarczy. Gra nie potrzebuje PHP, bazy danych ani backendu.
- Pliki `.wasm` powinny być wysyłane z typem **`application/wasm`**. Dołączony `.htaccess` ustawia go dyrektywą `AddType application/wasm .wasm` (wymaga serwera Apache i zezwolenia na `.htaccess` — na hostingach Apache zwykle jest dostępne; **potwierdź u home.pl**, czego nie mogłem zweryfikować).
- Kompresja gzip/deflate jest zalecana: `index.wasm` ma ok. 39 MB, a po kompresji gzip ok. 10 MB. `.htaccess` włącza ją, jeśli serwer ma `mod_deflate`.
- **Nie** są potrzebne nagłówki COOP/COEP (eksport jednowątkowy).
- Wszystkie ścieżki w eksporcie są względne, więc gra działa z podkatalogu `/gra/` (sprawdzone na lokalnym serwerze).

Jak sprawdzić MIME po wgraniu: w przeglądarce otwórz narzędzia deweloperskie (F12) → Sieć → odśwież stronę → kliknij `index.wasm` → nagłówek `Content-Type` powinien brzmieć `application/wasm`.

## Sterowanie

| Akcja | Komputer | Telefon / tablet |
|---|---|---|
| Ruch | WASD / strzałki | joystick: kciuk w lewej połowie ekranu |
| Celowanie | mysz | automatyczne (najbliższy przeciwnik) |
| Atak | lewy przycisk myszy / J | duży przycisk po prawej |
| Umiejętności | Q (lub PPM), R | dwa przyciski po prawej |
| Unik | Spacja / Shift | przycisk uniku |
| Interakcja | E / F / Enter | „Użyj” (pojawia się w pobliżu obiektu) |
| Eliksir | H | menu → Ekwipunek |
| Pauza, dziennik, mapa | Esc / Tab, M | przyciski w prawym górnym rogu |

## Zapis i prywatność

- Postęp zapisuje się automatycznie przy Kamieniach Iskry, po zadaniach i przy podróżach — w pamięci przeglądarki (`IndexedDB`, przez system plików `user://` Godota).
- Zapis jest wersjonowany i walidowany. Przy uszkodzeniu gra próbuje kopii zapasowej, a gdy i ta jest uszkodzona, informuje o tym i pozwala zacząć od nowa.
- Jeśli przeglądarka nie zapewnia trwałego zapisu (np. tryb prywatny), gra wyświetla ostrzeżenie i pozwala grać dalej.
- **Eksport/import zapisu** (menu → Zapis): pobranie pliku, wyświetlenie kodu do skopiowania, wklejenie kodu, wczytanie pliku. Importowane dane są traktowane jako niezaufane i sprawdzane.
- Brak analityki, reklam, kont, kluczy API i zbierania danych osobowych. Gra nie łączy się z żadnym serwerem poza pobraniem własnych plików.

## Jak dodać nowe zadanie

1. Dopisz obiekt do `godot/data/missions.json`. Wybierz `type` spośród `sequence`, `slots`, `marks` (tryby: `verify`, `toggles`, `redact`, `inspect`), `sort`, `compare`, `password`. Wymagane pola: `id`, `area`, `title`, `goal`, `data`, `hints`, `success`, `real_life`, `lesson`, opcjonalnie `world_flag` (flaga zmieniająca świat), `reward`, `focus` (punkt pokazywany kamerą), `ai_note`.
2. Postaw stację w obszarze: w `godot/data/areas/<obszar>.json` dodaj do `stations` wpis `{"mission": "<id>", "pos": [x, y]}`.
3. Jeśli zadanie ma coś zmienić w świecie, dodaj obiekt z tą samą flagą (`objects`: `gate`, `fogwall`, `water`, `conveyor`, `crates`, `flowerbed`, `shelves`, `lift`) albo most (`bridges` z polem `flag`).
4. Uruchom testy (poniżej) — sprawdzą m.in., czy stacja istnieje, jest osiągalna i czy zadanie da się rozwiązać.

## Testy

```bash
cd straznicy-iskry/godot
godot --headless -s res://tests/check_all.gd           # kompilacja skryptów + spójność danych
godot --headless -s res://tests/save_test.gd           # zapis, kopia zapasowa, walidacja, import/eksport
godot --headless res://tests/autotest_scene.tscn       # pełne przejście gry każdą klasą
godot --headless res://tests/perf_scene.tscn           # orientacyjny koszt logiki na klatkę w obszarach
```

W buildzie testowym (preset „Web (testy)”) w przeglądarce działają parametry `?autotest=1` (przejście gry) i `?tour=1` (wycieczka po ekranach do zrzutów). Wyniki rzeczywiście wykonanych testów są w [`docs/RAPORT_TESTOW.md`](docs/RAPORT_TESTOW.md).

## Licencje

Szczegóły w [`docs/LICENCJE.md`](docs/LICENCJE.md). W skrócie: kod gry, grafika (rysowana kodem) i dźwięki (syntezowane skryptem) powstały na potrzeby projektu. Czcionki Nunito i Cinzel są na licencji SIL OFL 1.1, a Godot Engine na licencji MIT.

## Znane ograniczenia

- Grafika jest wektorowa i rysowana kodem — spójna i lekka, ale prostsza niż ręcznie malowane sprite'y. Można ją później podmienić na ilustracje.
- Czas przejścia (30–45 min) jest **szacunkiem**, nie wynikiem testów z ludźmi — patrz raport testów.
- Gra nie była testowana na fizycznych telefonach ani w Safari/Firefoksie (szczegóły w raporcie).
- BLIK i automaty w grze działają na przygotowanych regułach — to nie jest prawdziwy model AI.
