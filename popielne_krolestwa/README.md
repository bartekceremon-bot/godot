# POPIELNE KRÓLESTWA

Mobilne MMORPG na Androida: klimat i mechaniki **Tibii** (widok z góry, kafelki 32×32, pixel art,
skille rosnące od używania, runy/czary z formułami) połączone z gospodarką i PvP w stylu
**Albion Online** (gospodarka graczy, „jesteś tym, co nosisz”, strefy ryzyka z full lootem).

> Świat został spalony przez upadłego boga Ognia. Gracze to **Popielnicy** – ocaleni, którzy
> odbudowują miasta i walczą o żyzne ziemie.

**Stan: ETAP 3 – PvP, strefy ryzyka i umiejętności broni + nowa oprawa 3D low-poly** (wersja 0.5.0) (patrz [Plan etapów](#plan-etapów)).

---

## Spis treści

1. [Co działa w ETAPIE 1](#co-działa-w-etapie-1), [ETAPIE 2](#co-doszło-w-etapie-2--ekonomia) i [ETAPIE 3](#co-doszło-w-etapie-3--pvp)
2. [Struktura projektu](#struktura-projektu)
3. [Szybki start – tryb „lokalny serwer” (komputer + telefon w tej samej sieci Wi-Fi)](#szybki-start--tryb-lokalny-serwer)
4. [Serwer na VPS (Docker)](#serwer-na-vps-docker)
5. [Ustawienie adresu serwera w kliencie](#ustawienie-adresu-serwera-w-kliencie)
6. [Budowanie i instalacja APK](#budowanie-i-instalacja-apk)
7. [Podpisywanie kluczem release](#podpisywanie-kluczem-release)
8. [Sterowanie](#sterowanie)
9. [Testy](#testy)
10. Decyzje podjęte w [ETAPIE 1](#decyzje-podjęte-w-etapie-1), [ETAPIE 2](#decyzje-podjęte-w-etapie-2) i [ETAPIE 3](#decyzje-podjęte-w-etapie-3)
11. [Plan etapów](#plan-etapów)
12. [Grafika, dźwięk, licencje](#grafika-dźwięk-licencje)

---

## Co działa w ETAPIE 1

- Rejestracja i logowanie (hasła hashowane scrypt), zapis postaci w SQLite (przy wylogowaniu, co 60 s i przy zatrzymaniu serwera).
- Miasto **Popielgród** (strefa ochronna, świątynia, bramy, skrzynie depozytu – aktywne od ETAPU 2) oraz zielona strefa 96×96 kafelków.
- Ruch po kafelkach w 8 kierunkach: **joystick** i **tap-to-move** (ścieżka A*), z przewidywaniem ruchu po stronie klienta i korektą serwera (anty-speedhack).
- 3 typy potworów z AI (pościg, powrót na spawn, respawn): **Szczur**, **Wilk**, **Popielny szkielet**.
- Walka **wręcz** (miecz/topór/maczuga) i **na dystans** (łuk, linia wzroku), automatyczny atak celu, pościg za celem.
- Czar leczący **exura** – przycisk na pasku lub formuła wpisana w czat.
- Loot na ziemi (dotknij, aby podnieść), **plecak** 20 slotów, **ekwipunek** 6 slotów (broń dwuręczna zdejmuje tarczę), mikstury.
- Doświadczenie i poziomy (krzywa z Tibii), skille rosnące od używania (miecz, topór, maczuga, dystans, magia, tarcza, wędkarstwo).
- Prosta kara za śmierć (−5% doświadczenia, odrodzenie w świątyni) – pełny system w ETAPIE 3.
- Widok innych graczy online, czat globalny z dymkami nad głową, lista `/online`.
- Wykrywanie serwera w sieci lokalnej (przycisk **„Szukaj w LAN”**).

## Co doszło w ETAPIE 2 – ekonomia

- **Zbieractwo:** ok. 140 złóż na mapie – drzewa (drewno), głazy (kamień), żyły rudy, kępy włókien – w tierach
  **T1–T4**: im dalej od miasta, tym wyższy tier (T3–T4 na Popielisku). Dotknij złoża – postać podejdzie i będzie
  zbierać, dopóki złoże się nie wyczerpie (odnawia się po 1–2 min). Wymaga narzędzia (siekiera drwala, kilof, sierp)
  o tierze ≥ tieru złoża. **Skóry** pochodzą z upolowanych zwierząt: szczur T1, **dzik** T2 (nowy), wilk T3,
  **żarowy ogar** T4 (nowy, Popielisko).
- **Drzewko specjalizacji** (przycisk **Spec.**): Drwal, Kamieniarz, Górnik, Zbieracz, Oskórowywacz, Rafinacja,
  Kowalstwo, Rzemiosło. Poziom rośnie od używania, odblokowuje tiery (T2 od 3, T3 od 6, T4 od 10), daje szansę
  na dodatkowy surowiec i lepszą jakość wyrobów.
- **Rafinacja** (Rafinator Zenon): kłody → deski, kamień → bloki, ruda → sztaby, włókno → płótno, skóra surowa →
  wyprawiona. T1 = 1 surowiec, T2+ = 2 surowce + 1 materiał tieru niżej (jak w Albionie).
- **Rzemiosło** – ~80 receptur T1–T4: Kuźnia (Kowal Gerwazy: miecze, topory, buławy, tarcze, pancerz płytowy,
  narzędzia) i Pracownia (Rzemieślniczka Jadwiga: łuki, pancerz skórzany i materiałowy).
  **Jakość** wyrobu: Zwykły → Dobry → Wyjątkowy → Doskonały → Arcydzieło (+0–30% do statystyk, kolorowa ramka).
  Brak klas – trzy typy pancerzy: płyta (pancerz), skóra (pancerz + zdrowie), płótno (mana).
  **Premia miasta:** Popielgród zwraca 25% materiałów przy rafinacji i 15% przy rzemiośle.
- **Rynek miejski** (Rynkowa Wanda): zlecenia sprzedaży i kupna między graczami, natychmiastowy zakup/sprzedaż,
  dopasowywanie zleceń, jakość minimalna, podatek 3%, anulowanie. Towar i złoto z transakcji trafiają do depozytu.
  Każde miasto ma osobny rynek (kolejne miasta w dalszych etapach).
- **Depozyt** (Bankier Oskar): osobny w każdym mieście, do 100 pozycji.
- **NPC ze słowami kluczowymi** (jak w Tibii): dotknij NPC albo napisz przy nim „witaj”, potem słowo z listy
  (np. „handel”, „rynek”, „depozyt”, „kuźnia”). **Kupiec Borys** sprzedaje narzędzia T1 i mikstury, skupuje wszystko
  za 20% wartości.
- **Udźwig:** 400 oz + 20 oz/poziom (widoczny w plecaku) – surowce ważą, transport ma znaczenie.
- Postacie z ETAPU 1 są automatycznie migrowane (stare przedmioty → nowe T1/T2, narzędzia T1 w prezencie).

## Co doszło w ETAPIE 3 – PvP

- **Strefy ryzyka** (pierścienie wokół świątyni Popielgrodu, widoczne na mapie, minimapie i jako napis pod zegarem;
  przy przekroczeniu granicy pojawia się komunikat):
  - **zielona** (miasto i okolice, złoża T1–T2) – brak PvP, śmierć = −5% doświadczenia, przedmioty zostają,
  - **żółta** (złoża T3) – PvP z czaszkami, śmierć = −7% doświadczenia i utrata ok. 30% stosów z plecaka,
  - **czerwona** (daleko od miasta i całe Popielisko, złoża T4) – pełne PvP, śmierć = −10% doświadczenia
    i **FULL LOOT**: cały plecak i ekwipunek zostają w zwłokach na 5 minut – każdy może je podnieść.
- **Walka z graczami:** dotknij innego gracza (albo przycisk **Atak**) w strefie żółtej/czerwonej. Przy ataku
  na niewinnego w żółtej strefie serwer ostrzega, że dostaniesz białą czaszkę (walka zaczyna się od razu).
- **Czaszki** (żółta strefa, jak w Tibii): atak na gracza bez czaszki, który cię nie zaatakował → **biała czaszka**
  (15 min, znika też po śmierci). **3 niesprawiedliwe zabójstwa w ciągu 24 h → czerwona czaszka** (2 h) –
  jej właściciel traci **wszystko** po śmierci w każdej strefie, a zabicie go nie daje czaszki. Samoobrona jest
  zawsze usprawiedliwiona.
- **Blokada strefy ochronnej:** po walce PvP przez 60 s nie wejdziesz do miasta (napis w oknie Postać).
- **Wylogowanie w walce:** postać zostaje w świecie jeszcze 30 s po rozłączeniu, jeśli walczyła z graczem.
- **Kara za śmierć:** strata doświadczenia (może spaść poziom) i części postępu skilli; zabójca-gracz dostaje
  doświadczenie (15 × poziom ofiary).
- **Błogosławieństwa** (Kapłanka Wiesława w świątyni, słowo „błogosławieństwo”, cena 100 + 20 × poziom): do 5;
  każde zmniejsza stratę doświadczenia i skilli o 16%, komplet 5 chroni plecak w żółtej strefie.
  Zużywają się przy śmierci poza zieloną strefą. Nie chronią przed full lootem w czerwonej strefie.
- **Umiejętności broni** (Albion – „jesteś tym, co nosisz”, bez klas): każda broń daje 3 przyciski na pasku akcji,
  kosztują manę i mają czas odnowienia (widoczny na przycisku):

  | Broń | 1 | 2 | 3 |
  |------|---|---|---|
  | Miecz | Potężne cięcie (180%) | Rozpłatanie (krwawienie 5 s) | Parowanie (½ obrażeń wręcz 4 s) |
  | Topór | Rąbnięcie (220%) | Wir (wszyscy wokół, 120%) | Szał (szybkie ataki 6 s) |
  | Buława | Ogłuszenie (1,5 s) | Miażdżenie (150%, ignoruje pancerz) | Żelazna skóra (+6 pancerza 8 s) |
  | Łuk | Celny strzał (200%, zasięg 7) | Strzała spowalniająca (5 s) | Deszcz strzał (obszar) |

- **Rozbójnik Zbych** (bot w trybie offline, czerwona czaszka) poluje na graczy poza zieloną strefą; inne boty
  bronią się, gdy je zaatakujesz.
- Nowa NPC **Kapłanka Wiesława** (słowa: „błogosławieństwo”, „śmierć”, „strefy”, „czaszki”), ikony czaszek nad
  graczami, ekran śmierci z listą strat, efekty umiejętności.

## Oprawa graficzna – 3D low-poly (Godot 4.5)

Od wersji 0.5.0 świat jest **trójwymiarowy** (styl low-poly, kamera z góry pod kątem jak w Albionie).
Serwer, protokół i mechaniki się nie zmieniły – świat 3D powstaje z tej samej mapy kafelków (1 kafelek = 1 jednostka).

| Element | Jak zrobiony |
|---------|--------------|
| Teren | Siatki generowane w kodzie (`scripts/world3d/world_builder.gd`) w kawałkach 16×16: płaskie cieniowanie, łagodne przejścia kolorów, trawa zmienia się wraz ze strefą (zielona → złota → wypalona), bruk miasta, marmur świątyni ze świecącym kręgiem run, żarzące się szczeliny Popieliska, wzgórza i las poza mapą |
| Woda | Shader `lowpoly_water.gdshader`: fale w wierzchołkach, fasetki, piana przy brzegu, połysk |
| Obiekty | Drzewa (liściaste, iglaste, jesienne, wypalone – kołyszą się na wietrze), skały, mury z blankami i chorągwiami, wieże z dachami przy bramach i narożnikach, stragany, skrzynie, kowadło, stół, piec z ogniem |
| Postacie | `character_model.gd`: modele z części animowane w kodzie (chód, oddech, cios, strzał z łuku, zbieranie, śmierć). **Wygląd zależy od ekwipunku**: hełm/zbroja/nogi/buty (płyta/skóra/płótno, kolor i materiał tieru), miecz/topór/buława/łuk, tarcza okrągła lub migdałowa z herbem. Każdy NPC ma własny strój |
| Potwory i złoża | Szczur, dzik, wilk, płonący ogar (świecące oczy, żar), szkielet; złoża T1–T4 wyglądają inaczej (brzoza, kasztanowiec, sosna, cedr, żyły miedzi…tytanu, len…ognista pokrzywa) i maleją w miarę wydobycia |
| Światło | Słońce z cieniami, **cykl dnia i nocy** (zachód słońca, księżyc), pochodnie i kosze ogniowe z migoczącym światłem, gracz niesie światło nocą, poświata (glow) ognia i żaru |
| Atmosfera | Mgła w kolorze strefy (błękitna / złota / czerwono-dymna), opadający popiół, w czerwonej strefie unoszący się żar |
| Efekty | Krew i iskry przy trafieniu, lecące strzały, słup światła przy awansie i leczeniu, fale umiejętności, gwiazdki ogłuszenia, znacznik dotknięcia |
| Interfejs | Imiona, paski życia i liczby obrażeń jako ostra nakładka 2D; HUD, okna i minimapa w stylu pixel-art (9-patch); ekran logowania ze scenką 3D (ognisko o zmierzchu) |
| Kamera | Płynne podążanie, wstrząs przy trafieniu, **przybliżanie** dwoma palcami / kółkiem myszy |

Dalsze kawałki świata budują się w tle (limit 5 ms na klatkę), zaczynając od najbliższych graczowi.
W menu gry: **„Efekty graficzne: wysokie/niskie”** – wyłącza cienie, poświatę i cząsteczki na słabszych telefonach.

### Grafiki interfejsu (PNG)

Ikony przedmiotów, ramki okien, przyciski i ikona aplikacji leżą w `client/assets/` (PNG + `atlas_index.json`).
Tworzy je generator pixel artu `client/tools/build_art.gd` (licencja CC0); po zmianie: `tools/build_assets.sh`.
Każdy PNG można podmienić ręcznie narysowanym (ten sam rozmiar).

## Struktura projektu

```
popielne_krolestwa/
├── docker-compose.yml       # serwer jedną komendą
├── PROTOKOL.md              # opis wiadomości klient <-> serwer
├── server/                  # Node.js + TypeScript, WebSocket, SQLite
│   ├── src/
│   │   ├── index.ts         # start, zamykanie z zapisem
│   │   ├── config.ts        # konfiguracja (zmienne środowiskowe)
│   │   ├── auth.ts          # hasła, walidacja nazw
│   │   ├── db/database.ts   # SQLite + migracje (łatwa zamiana na PostgreSQL)
│   │   ├── net/server.ts    # WebSocket, logowanie, anty-flood
│   │   ├── net/discovery.ts # wykrywanie serwera w LAN (UDP)
│   │   ├── game/world.ts    # symulacja świata: ruch, walka, AI, loot, czat
│   │   ├── game/map.ts      # generator mapy + linia wzroku
│   │   ├── game/entities.ts # gracz, potwór, przedmiot na ziemi
│   │   ├── game/inventory.ts, combat.ts, progression.ts, specs.ts
│   │   ├── game/systems/    # zbieractwo, ekonomia (NPC, sklep, depozyt, rynek, rzemiosło)
│   │   ├── game/economy/    # księga zleceń rynku, magazyn depozytów
│   │   ├── game/data/       # przedmioty T1–T4, receptury, NPC i miasta, złoża, potwory, czary
│   │   └── tools/bot.ts     # boty testowe
│   ├── test/                # testy jednostkowe i integracyjne
│   └── Dockerfile
├── client/                  # Godot 4.5 (GDScript)
│   ├── project.godot, export_presets.cfg
│   ├── scenes/              # main, game (scena 3D)
│   ├── shaders/             # low-poly: teren, obiekty, roślinność (wiatr), woda; winieta
│   ├── assets/              # grafiki interfejsu PNG, atlas_index.json
│   ├── scripts/autoload/    # Config, Net, GameData, Sprites (ikony), Sfx (dźwięk)
│   ├── scripts/game/        # scena gry: kamera, słońce, dzień/noc, sterowanie, pakiety
│   ├── scripts/world3d/     # świat 3D: generator terenu, modele postaci, ogień, efekty, loot, nakładka
│   ├── scripts/ui/          # logowanie, HUD, joystick, plecak, postać, NPC, sklep, depozyt,
│   │                        # rynek, rzemiosło, specjalizacje, okno ilości/ceny
│   ├── scripts/debug/       # automatyczny test klienta
│   └── tools/               # build_art.gd + art/ (generator ikon i interfejsu)
└── tools/                   # build_apk.sh (APK debug/release), build_assets.sh (grafiki)
```

---

## Szybki start – tryb „lokalny serwer”

Do testów na jednym komputerze + telefon w **tej samej sieci Wi-Fi**.

### 1. Uruchom serwer na komputerze

**Opcja A – Node.js** (wymaga Node.js ≥ 22.13):

```bash
cd popielne_krolestwa/server
npm install
npm run build
npm start
```

**Opcja B – Docker** (jedna komenda):

```bash
cd popielne_krolestwa
docker compose up -d --build
docker compose logs -f server      # podgląd logów
```

Serwer wypisze adresy, które można wpisać w telefonie, np.:

```
 Adresy do wpisania w kliencie (ta sama sieć Wi-Fi):
   ws://192.168.1.23:7171
```

> W Dockerze serwer widzi tylko adres wewnętrzny kontenera (np. 172.17.x.x) – w telefonie wpisz
> **adres IP komputera** w sieci Wi-Fi (Windows: `ipconfig`, Linux/macOS: `ip a` / `ifconfig`).
> Wykrywanie „Szukaj w LAN” najpewniej działa przy uruchomieniu przez Node.js (opcja A).

### 2. Otwórz porty w zaporze komputera

- **TCP 7171** – gra (WebSocket),
- **UDP 7172** – wykrywanie serwera w LAN (opcjonalne).

Windows (PowerShell jako administrator):

```powershell
New-NetFirewallRule -DisplayName "Popielne Krolestwa" -Direction Inbound -Protocol TCP -LocalPort 7171 -Action Allow
New-NetFirewallRule -DisplayName "Popielne Krolestwa LAN" -Direction Inbound -Protocol UDP -LocalPort 7172 -Action Allow
```

Linux (ufw): `sudo ufw allow 7171/tcp && sudo ufw allow 7172/udp`

### 3. Połącz się z telefonu

Zainstaluj APK (patrz niżej), uruchom grę, naciśnij **„Szukaj w LAN”** albo wpisz adres ręcznie
(wystarczy samo IP, np. `192.168.1.23` – klient dopisze `ws://` i port `7171`).
Wpisz nazwę postaci i hasło, naciśnij **„Nowa postać”** (pierwszy raz) lub **„Zaloguj”**.

Grę można też uruchomić na komputerze: otwórz `client/project.godot` w Godot 4.5 i naciśnij F5
(adres `ws://127.0.0.1:7171`).

---

## Serwer na VPS (Docker)

Przykład dla Ubuntu 22.04/24.04 (VPS z publicznym IP, min. 1 GB RAM).

```bash
# 1. Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # wyloguj się i zaloguj ponownie

# 2. Kod gry
git clone <adres-repozytorium> gra && cd gra/popielne_krolestwa

# 3. Start (w tle, restart po awarii i po restarcie VPS)
docker compose up -d --build

# 4. Zapora
sudo ufw allow OpenSSH
sudo ufw allow 7171/tcp
sudo ufw enable
```

W kliencie wpisz `ws://<IP_VPS>:7171`.

Przydatne komendy:

| Czynność | Komenda |
|----------|---------|
| Logi | `docker compose logs -f server` |
| Restart | `docker compose restart server` |
| Zatrzymanie (z zapisem postaci) | `docker compose down` |
| Aktualizacja | `git pull && docker compose up -d --build` |
| Kopia bazy | `cp data/game.db backup-$(date +%F).db` (najlepiej przy zatrzymanym serwerze) |

Baza SQLite leży w `popielne_krolestwa/data/game.db` (wolumen Dockera). Port i ścieżkę bazy zmienisz
w `docker-compose.yml` (`PORT`, `DB_PATH`, `DISCOVERY_PORT` – `0` wyłącza wykrywanie LAN).

**Szyfrowanie (wss://) – opcjonalnie:** postaw przed serwerem reverse proxy z certyfikatem, np. Caddy
(`gra.twojadomena.pl { reverse_proxy 127.0.0.1:7171 }`) i wpisz w kliencie `wss://gra.twojadomena.pl`.

---

## Ustawienie adresu serwera w kliencie

- **W grze:** pole „Adres serwera” na ekranie logowania. Adres jest zapamiętywany
  (`user://settings.cfg` na telefonie), więc wpisujesz go tylko raz.
- **Domyślny adres w buildzie:** zmień `server_url` w `client/scripts/autoload/config.gd`
  (np. na adres swojego VPS) i zbuduj APK ponownie.
- Formaty: `192.168.1.23`, `192.168.1.23:7171`, `ws://moj-serwer.pl:7171`, `wss://gra.domena.pl`.

---

## Budowanie i instalacja APK

### Wymagania

1. **Godot 4.5.1** (standardowy, nie .NET): <https://godotengine.org/download>
2. **Szablony eksportu** 4.5.1: w edytorze *Edytor → Zarządzaj szablonami eksportu → Pobierz*.
3. **JDK 17+** (np. OpenJDK 17 lub 21).
4. **Android SDK** z pakietami `platform-tools`, `build-tools` (np. 35.0.0) i `platforms;android-35`
   – najprościej przez Android Studio albo `cmdline-tools`:
   ```bash
   sdkmanager "platform-tools" "build-tools;35.0.0" "platforms;android-35"
   ```

### Opcja A – skrypt (Linux/macOS/WSL)

```bash
cd popielne_krolestwa
export ANDROID_HOME=$HOME/Android/Sdk
export GODOT=/sciezka/do/Godot_v4.5.1-stable_linux.x86_64   # jeśli "godot" nie jest w PATH
tools/build_apk.sh
# -> build/popielne_krolestwa-debug.apk (podpisany kluczem debug)
```

Skrypt sam generuje klucz debug (`build/debug.keystore`) i ustawia ścieżki SDK w ustawieniach Godota.

### Opcja B – edytor Godot (Windows/macOS/Linux)

1. *Edytor → Ustawienia edytora → Export → Android*: ustaw **Android SDK Path** i **Java SDK Path**
   (klucz debug Godot tworzy automatycznie).
2. Otwórz `client/project.godot`, *Projekt → Eksportuj… → Android → Eksportuj projekt* (zaznacz „Eksport z debugowaniem”).

### Instalacja na telefonie

- Przez USB (włączone *Debugowanie USB* w opcjach programisty):
  `adb install -r build/popielne_krolestwa-debug.apk`
- Albo skopiuj plik APK na telefon i otwórz go (zezwól na instalację z nieznanych źródeł).

APK zawiera biblioteki **arm64-v8a** i **armeabi-v7a** (wszystkie współczesne telefony), minSdk 24
(Android 7.0+, więc Android 8 jest obsługiwany), targetSdk 35. Do testów na emulatorze x86_64 włącz
`architectures/x86_64=true` w `client/export_presets.cfg`.

---

## Podpisywanie kluczem release

Klucz debug nadaje się tylko do testów. Do dystrybucji (np. Google Play) utwórz **własny klucz release**
– raz, i przechowuj go bezpiecznie (utrata klucza = brak możliwości aktualizacji aplikacji):

```bash
keytool -genkeypair -v -keystore popielne-release.keystore -alias popielne \
  -keyalg RSA -keysize 2048 -validity 10000
```

Budowanie wersji release:

```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$PWD/popielne-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=popielne          # alias klucza
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='twoje-haslo'
tools/build_apk.sh release
# -> build/popielne_krolestwa-release.apk
```

Weryfikacja podpisu: `apksigner verify --print-certs build/popielne_krolestwa-release.apk`.
W edytorze Godot te same dane wpisuje się w presecie Android (*Keystore → Release*).
**Nie commituj pliku keystore ani hasła do repozytorium.** Przed publikacją zwiększ `version/code`
w `client/export_presets.cfg`. Google Play wymaga formatu AAB – to wymaga eksportu z Gradle
(`gradle_build/use_gradle_build=true`, `export_format=1`); zaplanowane na ETAP 5.

---

## Sterowanie

| Akcja | Telefon | Komputer |
|-------|---------|----------|
| Ruch | joystick (lewy dół) lub dotknij pola | strzałki / WASD, kliknięcie |
| Przybliżenie kamery | dwa palce (szczypanie) | kółko myszy |
| Atak | dotknij potwora (ponownie – przerwij) lub **Atak** (najbliższy / następny) | kliknięcie |
| Leczenie | przycisk **exura** lub wpisz `exura` w czat | – |
| Mikstury | przyciski z czerwoną / niebieską miksturą | – |
| Podnoszenie lootu | dotknij przedmiotu na ziemi (postać podejdzie) | kliknięcie |
| Plecak / ekwipunek | **Plecak** → dotknij przedmiotu → Użyj / Załóż / Zdejmij / Upuść | – |
| Skille, poziom | **Postać** | – |
| Czat | pole na dole; `/online`, `/pomoc` | Enter |
| Zbieranie | dotknij złoża (drzewo, głaz, żyła, włókna) | kliknięcie |
| Rozmowa z NPC | dotknij NPC → przyciski słów kluczowych (lub pisz w czacie) | kliknięcie |
| Specjalizacje | **Spec.** | – |
| Umiejętności broni | 3 przyciski nad **Atak** (zależne od broni w ręce) | – |
| Atak na gracza | dotknij gracza w strefie żółtej/czerwonej | kliknięcie |
| Błogosławieństwa | Kapłanka w świątyni → „błogosławieństwo” | – |

Wręcz postać sama podchodzi do celu; z łukiem zatrzymuje się w zasięgu strzału (6 pól, potrzebna linia wzroku).

---

## Testy

```bash
cd server
npm test                                  # testy jednostkowe + integracyjne (prawdziwy WebSocket)
npm run bot -- ws://127.0.0.1:7171 5      # 5 botów spacerujących po mieście
```

Automatyczny test klienta (logowanie, ruch, walka, czar, plecak, zrzuty ekranu):

```bash
godot --path client -- --autotest=ws://127.0.0.1:7171,Tester,haslo1 --shots=/tmp/zrzuty
# scenariusz ETAPU 2 (domyślny): NPC, sklep, zbieranie, rafinacja, rynek, depozyt, specjalizacje
# scenariusz ETAPU 1: dodaj --scenario=etap1
# scenariusz ETAPU 3: dodaj --scenario=etap3 (kapłanka, strefy, umiejętność, okno postaci)
# przegląd świata 3D: --scenario=widoki (jezioro, Popielisko, krawędź, brama, rynek); ekran logowania: --scenario=login
# pora dnia na zrzutach: --day / --dusk / --night
```

---

## Decyzje podjęte w ETAPIE 1

1. **Katalog `popielne_krolestwa/`** – repozytorium zawiera kod silnika Godot, więc gra żyje w osobnym
   podkatalogu i nie miesza się z silnikiem.
2. **Godot 4.5.1, renderer GL Compatibility** – najlepsza zgodność ze starszymi telefonami (Android 8) i 2D.
3. **Rozdzielczość bazowa 1280×720**, skalowanie `canvas_items` + `expand` (szersze telefony widzą więcej
   świata), kamera z przybliżeniem ×2 (~20×11 kafelków), orientacja pozioma (sensor).
4. **Protokół JSON przez WebSocket** – czytelny i łatwy do debugowania; serwer wysyła stan widocznego
   obszaru tylko przy zmianie (10 ticków/s). Przy większej liczbie graczy można przejść na binarny.
5. **SQLite przez wbudowany `node:sqlite`** (Node 22) – zero natywnych zależności (łatwy Docker);
   dostęp tylko przez klasę `Database` + migracje w standardowym SQL → prosta migracja na PostgreSQL.
6. **Jedno konto = jedna postać** (nazwa konta = nazwa postaci) – wiele postaci na konto w późniejszym etapie.
7. **Przewidywanie ruchu na kliencie** + „budżetowanie” ruchu na serwerze (tolerancja 150 ms na jitter,
   bez trwałego przyspieszenia) – płynne sterowanie bez możliwości speedhacka.
8. **Gracze nie blokują się nawzajem** (tylko potwory blokują pola) – zapobiega blokowaniu bram miasta.
9. **Loot ląduje na ziemi** (znika po 2 min) zamiast okna zwłok – prostsze na dotyku; okno zwłok można dodać później.
10. **Atak co 2 s** jak w Tibii, bez zużycia strzał (amunicja dojdzie z craftingiem w ETAPIE 2).
    Walka bez broni używa skilla maczugi (brak osobnego skilla pięści).
11. **Brak klas** już teraz: postać startuje z mieczem, tarczą i łukiem – styl walki wynika z założonej broni.
12. **Kara za śmierć w ETAPIE 1:** −5% doświadczenia (może obniżyć poziom), ekwipunek zostaje (zielona strefa).
13. **Czat globalny** (wszyscy online) + dymki nad głową w zasięgu wzroku; formuły czarów (`exura`)
    mają własny cooldown i nie podlegają limitowi czatu.
14. **Grafika i dźwięk generowane w kodzie** (`Sprites`, `Sfx`) – zero zewnętrznych assetów,
    brak problemów licencyjnych; łatwo podmienić na ręcznie rysowane sprite'y później.
15. **Wykrywanie serwera w LAN przez broadcast UDP** – tryb lokalny bez wpisywania IP.
16. **APK tylko dla ARM** (arm64-v8a + armeabi-v7a, ~57 MB) – x86_64 włączane opcjonalnie dla emulatorów.
17. **Deterministyczny generator mapy** (stały seed) – ten sam świat po każdym restarcie; w ETAPIE 2+
    mapa może zostać zapisana jako plik i edytowana ręcznie.

## Decyzje podjęte w ETAPIE 2

1. **Tiery T1–T4 w zielonej strefie** (T3–T4 daleko od miasta i na Popielisku). W ETAPIE 3 obszary T4+ staną się
   strefą żółtą/czerwoną zgodnie z koncepcją świata.
2. **Ekwipunek generowany z szablonów** (20 szablonów × 4 tiery) – statystyki rosną o 30% na tier; wymagany poziom
   postaci T2: 6, T3: 12, T4: 20 (Tibia) + wymagana specjalizacja do wytworzenia (Albion).
3. **Jakość** jest cechą egzemplarza (`q` w stosie), nie osobnym przedmiotem – stosy łączą się tylko przy tej samej jakości.
4. **Skóry z polowania, nie ze złóż** – każde zwierzę daje skórę swojego tieru, jeśli poziom Oskórowywacza wystarcza.
5. **Narzędzia wystarczy mieć w plecaku** (bez osobnego slotu i bez zużycia) – prościej na telefonie; wytrzymałość
   może dojść przy balansie (ETAP 5).
6. **Potwory nie wypadają już gotowego ekwipunku** – tylko złoto, surowce i mikstury. Ekwipunek tworzą gracze
   (NPC sprzedaje wyłącznie narzędzia T1 i mikstury).
7. **Złoto pozostaje przedmiotem w plecaku** (jak w Tibii, a w ETAPIE 3 będzie tracone przy śmierci w PvP).
   Rynek realizuje płatności z plecaka, a wpływy/zakupy „na odległość” trafiają do depozytu miasta.
8. **Anty-duplikacja:** każda operacja rynku/depozytu wykonuje się w jednej transakcji SQL razem z zapisem postaci.
9. **Rynek:** nowe zlecenie najpierw realizuje się z czekającymi (po ich cenie), reszta czeka w księdze; podatek 3%
   płaci sprzedający; limit 20 zleceń na gracza; zlecenia nie wygasają (wygasanie – ETAP 5).
10. **Zwrot materiałów** (jak „resource return rate” w Albionie) jako premia miasta; każde z 3 miast dostanie inną premię,
    gdy pojawią się pozostałe miasta.
11. **Złoża nie blokują ruchu** (można przez nie przejść) – żeby losowo rozmieszczone złoża nie zamykały przejść;
    NPC blokują pole jak potwory.
12. **Okna handlu otwiera rozmowa z NPC** (zamiast osobnych kafelków-przycisków) – spójne z Tibią i wygodne na dotyku;
    odejście od NPC zamyka okna.

## Decyzje podjęte w ETAPIE 3

1. **Strefy jako pierścienie wokół jednego miasta** (odległość od świątyni): zielona do 22 pól, żółta do 34,
   czerwona dalej oraz całe Popielisko. Tiery złóż dopasowane do stref: T1–T2 zielona, T3 żółta, T4 czerwona.
   Tiery T5–T8, dwa kolejne miasta i Czarna Strefa (T8, terytoria gildii) – w ETAPIE 4 razem z powiększeniem mapy.
2. **Czaszki tylko w żółtej strefie** (w czerwonej wszyscy są uczciwym celem, jak w Albionie); w zielonej PvP jest
   całkowicie wyłączone po stronie serwera.
3. **Utrata w żółtej strefie = losowe ~30% stosów plecaka** (ekwipunek zostaje) – kompromis między „tracisz część
   torby” ze specyfikacji a frustracją na telefonie. Komplet 5 błogosławieństw chroni plecak.
4. **Full loot zostaje w zwłokach 5 minut** jako przedmioty na ziemi (każdy może je podnieść) zamiast okna „ciała” –
   działa z istniejącym systemem lootu i dotykiem.
5. **Kara za śmierć:** 5/7/10% doświadczenia (zielona/żółta/czerwona) i ta sama proporcja postępu skilli;
   każde błogosławieństwo −16% kary (5 = −80%). Cena rośnie z poziomem: 100 + 20 × poziom złota za sztukę.
6. **Umiejętności broni zamiast klas:** 3 na typ broni (miecz, topór, buława, łuk), dostępne od razu, koszt many
   + cooldown; rosną od nich skille broni (+2 próby). Tarcza i zbroja nie dają umiejętności (być może w ETAPIE 5).
7. **Blokada strefy ochronnej 60 s i wylogowanie w walce 30 s** – żeby nie dało się uciec z walki do miasta ani
   zamykając aplikację.
8. **Zabójca-gracz dostaje doświadczenie** (15 × poziom ofiary), a zabicie czerwonej czaszki nigdy nie jest karane.
9. **Protokół pozostał w wersji 2** – nowe pola i wiadomości są dopisane zgodnie wstecz (starsze serwery/klienci
   z ETAPU 2 muszą być jednak zaktualizowani razem, bo baza dostaje migrację 3 – kolumnę `pvp`).

## Decyzje – nowa oprawa 3D (wersja 0.5.0)

1. **3D low-poly zamiast pixel artu 2D** (na życzenie) przy zachowaniu serwera, protokołu i wszystkich mechanik –
   świat 3D powstaje z tej samej mapy kafelków, więc stare serwery i zapisy postaci działają bez zmian.
2. **Modele tworzone w kodzie** (bez zewnętrznych plików .glb): środowisko nie ma dostępu do serwisów z assetami,
   a proceduralne modele dają spójny styl, małe APK (~28 MB arm64) i wygląd zależny od ekwipunku i tieru.
3. **Renderer Compatibility (OpenGL ES 3 / WebGL 2)** – ten sam na Androidzie i w przeglądarce, działa na starszych
   telefonach (Android 8+). Cienie tylko od słońca, światła pochodni bez cieni.
4. **Kamera stała (bez obrotu)** – sterowanie joystickiem i tapnięciem pozostaje intuicyjne jak w Tibii/Albionie;
   dodane przybliżanie.
5. **Imiona i paski życia w 2D nad 3D** – czytelne w każdej skali ekranu.
6. **Trawa i mgła zmieniają kolor wraz ze strefą** – od razu widać, że wchodzisz w niebezpieczny teren.

## Plan etapów

- [x] **ETAP 1** – grywalne MVP.
- [x] **ETAP 2** – ekonomia: zbieractwo, crafting, tiery T1–T4, rynek miejski, NPC handlarze, depozyt.
- [x] **ETAP 3** – PvP: strefy żółta i czerwona, full loot, czaszki, kara za śmierć, błogosławieństwa, umiejętności broni.
- [ ] **ETAP 4** – gildie, Czarna Strefa (Popielisko), terytoria, bossowie świata, wierzchowce.
- [ ] **ETAP 5** – balans, tutorial, ustawienia grafiki, optymalizacja baterii, ikona i ekran startowy.

## Grafika, dźwięk, licencje

Wszystkie modele 3D (teren, drzewa, budowle, postacie, potwory), grafiki interfejsu, ikona i efekty dźwiękowe
są **generowane proceduralnie w kodzie** tego projektu (`client/scripts/world3d/`, `client/tools/build_art.gd`,
`client/scripts/autoload/sfx.gd`) i udostępniane jako **CC0**. Projekt nie zawiera żadnych
assetów z Tibii ani Albion Online. Czcionka: domyślna czcionka Godota (Open Sans, licencja OFL).
