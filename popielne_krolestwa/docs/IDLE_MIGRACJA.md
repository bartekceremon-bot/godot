# Popielne Królestwa Idle – analiza projektu 0.9.1 i plan migracji

Wersja idle/clicker powstała **na bazie** Popielnych Królestw 0.9.1 (MMO), a nie od zera.
Zmienia się pętla gry (KLIK → ATAK → OBRAŻENIA → ZABICIE → ŁUP → ZŁOTO/XP → ULEPSZENIE → SILNIEJSZY WRÓG),
świat, content i stylistyka zostają. Klasyczne MMO jest nadal dostępne (menu → „Klasyczne MMO”).

## 1. Inwentaryzacja projektu 0.9.1

| Obszar | Co jest w projekcie |
|---|---|
| Sceny | `scenes/main.tscn` (logowanie / gra MMO), `scenes/game.tscn` (świat 3D). Nowa: `scenes/idle_main.tscn` |
| Skrypty klienta | 77 plików `.gd`: autoloady (Config, Net, GameData, Sprites, Sfx), `world3d/` (MeshKit, CharacterModel, CreatureModels, Entity3D, Fx3D, WorldBuilder, WorldProps, TreeModels, FarWorld), `ui/` (HUD, okna, joystick), `game/game.gd`, `debug/autotest.gd` |
| Serwer | Node.js/TypeScript: świat 224×224, walka, PvP, gildie, terytoria, rynek, rzemiosło, czary, zadania, zapis SQLite |
| Assety | atlas ikon przedmiotów (`assets/items/items.png` + `atlas_index.json`), 68 grafik PNG (UI 9-patch, ikony HUD i czarów, ramki, paski, splash), 12 shaderów (low-poly obiekty, teren, niebo z chmurami, liście, trawa, woda, lawa), czcionka DejaVu Serif |
| Ikony | 42 rodzaje ikon przedmiotów × 9 tierów, 22 ikony HUD i czarów (+10 nowych: craft, quest, map, shop, gem, ash, mount, market, prestige, chest) |
| Przedmioty | 264: surowce i materiały 5 rodzajów × T1–T8 (drewno/deski, kamień/bloki, ruda/sztaby, włókno/płótno, skóra surowa/wyprawiona), 21 szablonów ekwipunku × T1–T8, złoto, mięso, kość, mikstury życia/many (+wielkie), 4 trofea bossów, 5 wierzchowców |
| Ekwipunek | broń: miecz, topór, buława, łuk, kostur; tarcza; pancerz płytowy / skórzany / materiałowy (głowa, tułów, nogi, stopy); narzędzia: siekiera, kilof, sierp; jakość 1–5 (Zwykły…Arcydzieło) |
| Czary | 18 w 5 szkołach (Światło, Ogień, Lód, Błyskawica, Nekromancja) z ikonami, formułami, odnowieniem, maną |
| Wierzchowce | koń, łoś szronowy, wielbłąd, wilk bojowy, popielny drake |
| Zadania | 22 zadania Kroniki w 3 miastach (łańcuchy, powtarzalne): zabij / zbierz / dotrzyj |
| NPC | 27 NPC w 3 miastach (bankier, rynek, kupiec, kowal, rzemieślnik, rafinator, kapłan, stajenny, mistrz gildii) |
| Lokacje | 3 miasta (Popielgród, Szronogród, Złotopiask), 7 krain (łąki, puszcza, śnieg, góry, pustynia, moczary, popiół), Czarna Strefa / Świątynia Ognia |
| Potwory | 29 zwykłych T1–T8 + 4 bossów świata (Król Szronu, Pustynny Czerw, Matka Moczarów, Żarogniew) |
| Ekonomia | złoto, skup NPC (20% wartości), sklepy NPC, rynek graczy z podatkiem, depozyty, rafinacja i rzemiosło ze zwrotem materiałów |
| Statystyki | poziom/XP, skille (miecz, topór, maczuga, dystans, magia, tarcza), specjalizacje, zdrowie, mana, atak, obrona, pancerz, siła czarów |
| Efekty | Fx3D: iskry, krew, pociski, pioruny, meteor, lodowe kolce, obłoki, aury, błyski; pogoda (deszcz, burza, śnieg) |
| Audio | Sfx – dźwięki syntezowane (trafienie, leczenie, awans, śmierć, rzemiosło, grzmot…) |

## 2. Klasyfikacja

**Zachowane bez zmian** (używane przez wersję idle):
- wszystkie dane contentu – eksportowane z serwera do `client/data/content/*.json` (`tools/export_idle_data.js`),
- modele 3D postaci, potworów, bossów i wierzchowców (CharacterModel, CreatureModels, Entity3D),
- efekty czarów (Fx3D), drzewa i obiekty krajobrazu (WorldProps), shadery, niebo,
- ikony przedmiotów i czarów, motyw UI (UiTheme – ramki, przyciski, paski), czcionka, dźwięki (Sfx),
- nazewnictwo: nazwy przedmiotów, potworów, czarów, NPC, miast, krain.

**Wykorzystane po adaptacji:**
- krainy → 8 regionów po 10 etapów (elita na 5., boss na 10.), potem Kręgi Popiołu,
- bestiariusz i tabele łupu MMO → wrogowie regionów i łup,
- bossowie świata → bossowie regionów z czasem 30 s,
- ekwipunek → 6 slotów z czytelnymi premiami (obrażenia, krytyk, DPS, zdrowie, obrona, złoto, XP, mana),
- jakość 1–5 → rzadkość Zwykły/Niezwykły/Rzadki/Epicki/Legendarny,
- receptury MMO (rafinacja, kuźnia, pracownia) → CRAFT z odblokowaniem wraz z postępem,
- surowce → waluta ulepszeń ekwipunku (główny „pochłaniacz” surowców),
- narzędzia zbierackie → pasywna premia do zdobywanych surowców,
- czary → umiejętności clickera (odnowienie, mana, efekt, poziom ulepszenia, rzucanie automatyczne),
- wierzchowce → stałe premie (złoto, XP, offline, obrażenia) z fragmentów,
- zadania Kroniki → cele clickera (zabij potwory regionu, zdobądź surowce, dotrzyj do regionu),
- NPC → najemnicy drużyny (Strażnik, Kapłanka Wiesława, Kowal Gerwazy, Mistrz gildii Zawisza…) i kupcy targu,
- sklep i rynek → Kupiec (mikstury, surowce, ekwipunek, wzmocnienia) i Targ (oferty kupców trzech miast),
- mikstury i mięso → leczenie w walce z bossem (automatycznie lub ręcznie),
- trofea bossów, mięso, kości → alchemia (tymczasowe wzmocnienia) lub sprzedaż.

**Zastąpione nowym systemem clickera:**
- chodzenie, joystick, kamera świata, streaming kawałków mapy → ekran walki z dioramą regionu,
- walka turowa z serwerem → dotyk, DPS najemników, krytyki, obrażenia w czasie,
- logowanie, sieć, serwer → lokalny zapis (SaveManager) i postęp offline,
- skille i specjalizacje → poziom bohatera, Trening ciosu, ekwipunek, Ołtarz Popiołu (prestiż).

**Usunięte z wersji idle** (pozostają tylko w klasycznym MMO):
- PvP, czaszki, strefy, pełny łup po śmierci, gildie, terytoria i obeliski, depozyty, dom gracza, czat, udźwig.

## 3. Architektura wersji idle

`scripts/idle/` – `game_manager.gd` (autoload **Idle**, magistrala zdarzeń i stan), moduły:
PlayerStats, ProgressionManager, EnemyManager, CombatManager, InventoryManager, EquipmentManager, LootManager,
CraftingManager, QuestManager, SpellManager, MercenaryManager, MountManager, ShopManager, MarketManager,
PrestigeManager, SaveManager, OfflineProgressManager, AudioManager; `idle_db.gd` – dane z JSON.

`scripts/idle/ui/` – UIManager (`idle_main.gd`), CombatScreen, BattleView (3D), IdleUI (elementy), zakładki w `panels/`.

Dane projektowe (łatwe do edycji): `client/data/idle/` – regiony, najemnicy, czary idle, wierzchowce,
prestiż, receptury alchemii, zlecenia. Content MMO: `client/data/content/` (generowany).

## 4. Testy

- `godot --headless --path client res://tests/idle_test.tscn` – pętla gry, bossowie, łup, ulepszenia, rzemiosło,
  czary, zadania, sklep, targ, wierzchowce, zapis i uszkodzony zapis, offline, odrodzenie.
- `godot --headless --path client res://tests/balance_sim.tscn -- --hours=6` – symulacja balansu (chciwy bot).
- `godot --path client -- --idle-shots=/katalog` – przegląd wszystkich ekranów ze zrzutami.
