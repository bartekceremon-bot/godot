# Architektura

## Przepływ ekranów

`main.tscn` → `title` (animowany, dźwięk po „Graj”) → `intro` (scenka, można pominąć) → `class_select` → `world`.
Z zapisem: `title` → „Graj dalej” → `world` (od ostatniego Kamienia Iskry). Przejścia obsługuje `Router` (zanikanie, pauza, orientacja).

## Autoloady (`scripts/core`)

| | Rola |
|---|---|
| `Data` | wczytuje JSON z `data/` (treści oddzielone od logiki) |
| `Settings` | ustawienia gracza, mapa wejścia, tryb dotyku |
| `GameState` | klasa, poziom, PD, ekwipunek, flagi świata, zadania, zapis/odczyt, walidacja, eksport/import |
| `Audio` | magistrale Music/SFX, pula efektów, przenikanie muzyki |
| `Router` | zmiana scen, orientacja (720×1280 w pionie, 1280×720 w poziomie), safe areas, utrata fokusu |

## Świat

- `World` (`scripts/world/world.gd`) — kontroler sceny gry: obszar, gracz, BLIK, kamera, niebo i chmury z paralaksą, drobiny, interfejs, podróże, śmierć i odrodzenie, finał. Udostępnia usługi efektów (`burst`, `ring`, `float_text`…).
- `Area` buduje obszar z `data/areas/*.json`: wyspy (`island.gd`, klif = warstwy w dół), mosty (`bridge.gd`), rekwizyty (`prop.gd`), trawa (`grass.gd` + shader), obiekty zmieniane flagami (`world_object.gd`), interakcje (`interactable.gd`), przeciwnicy, boss, wyzwalacze.
- **Kolizje** liczone są z sumy wielokątów chodliwych (wyspy pomniejszone o margines + zbudowane mosty). Po zbudowaniu mostu granica jest przeliczana. Bramy, ściany iluzji i skrzynie to osobne ciała statyczne wyłączane flagą.
- Głębia: sortowanie Y encji, cienie, klify wysp, chmury z paralaksą pod wyspami, elementy pierwszego planu z paralaksą (półprzezroczyste nad graczem).

## Zadania

`puzzle_panel.gd` otwiera zadanie i tworzy silnik według pola `type`:

| typ | silnik | zadania |
|---|---|---|
| `sequence` | ułóż kroki | lampa, most, przenośnik |
| `slots` | złóż z części | portal (cel/kontekst/ograniczenia/format), nawadnianie (kiedy/jeśli/to) |
| `marks` | zaznacz | automat-ogrodnik (`verify`), uprawnienia (`toggles`), tłumacz (`redact`), kruk (`inspect`) |
| `compare` | wybierz źródło | trzy echa |
| `sort` | przyporządkuj | fakty/opinie |
| `password` | zbuduj hasło | skarbiec |

Ukończenie zadania → `GameState.complete_mission` → nagrody + `world_flag` → obiekty świata reagują animacją, kamera pokazuje zmianę (`focus`). Błędy nie odbierają zdrowia; po błędzie gracz widzi wyjaśnienie, może wziąć podpowiedź i spróbować ponownie.

## Walka

`player.gd` (ruch, unik z nietykalnością, celowanie myszą lub wspomagane), `abilities.gd` (ataki i umiejętności 4 klas), `projectile.gd`, `ability_node.gd` (pole, dron, wieżyczka), `enemy.gd` (stany: bezczynność → pościg → zapowiedź → atak → odpoczynek, smycz do punktu startu), `boss.gd` (fazy, iluzje, Kamienie Prawdy, podpowiedź po dwóch pomyłkach).

## Interfejs

HUD z osobnymi układami dla szerokich i wąskich ekranów, sterowanie dotykowe z osobnym śledzeniem każdego palca, dialogi, menu pauzy (dziennik, ekwipunek, mapa, postać, ustawienia, zapis), scenki. Motyw w kolorach marki (`ui_theme.gd`) skaluje tekst wg ustawień.

## Wydajność

- Brak tekstur poza jedną miękką plamą światła 128×128 (generowaną w pamięci). Statyczna geometria jest rysowana raz i buforowana przez renderer.
- Ruch trawy i wody liczą shadery (bez przeliczania geometrii co klatkę).
- Limity: maks. 160 efektów naraz, ograniczone cząsteczki (36, w trybie niskim 14), mniej trawy i mgły w trybie niskim; tryb ograniczonych animacji zmniejsza ruch, błyski i drgania.
- Brak świateł 2D i pełnoekranowego rozmycia.
