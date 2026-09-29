# POPIELNE KRÓLESTWA

Mobilne MMORPG na Androida: klimat i mechaniki **Tibii** (widok z góry, kafelki 32×32, pixel art,
skille rosnące od używania, runy/czary z formułami) połączone z gospodarką i PvP w stylu
**Albion Online** (gospodarka graczy, „jesteś tym, co nosisz”, strefy ryzyka z full lootem).

> Świat został spalony przez upadłego boga Ognia. Gracze to **Popielnicy** – ocaleni, którzy
> odbudowują miasta i walczą o żyzne ziemie.

**Stan: ETAP 1 – grywalne MVP** (patrz [Plan etapów](#plan-etapów)).

---

## Spis treści

1. [Co działa w ETAPIE 1](#co-działa-w-etapie-1)
2. [Struktura projektu](#struktura-projektu)
3. [Szybki start – tryb „lokalny serwer” (komputer + telefon w tej samej sieci Wi-Fi)](#szybki-start--tryb-lokalny-serwer)
4. [Serwer na VPS (Docker)](#serwer-na-vps-docker)
5. [Ustawienie adresu serwera w kliencie](#ustawienie-adresu-serwera-w-kliencie)
6. [Budowanie i instalacja APK](#budowanie-i-instalacja-apk)
7. [Podpisywanie kluczem release](#podpisywanie-kluczem-release)
8. [Sterowanie](#sterowanie)
9. [Testy](#testy)
10. [Decyzje podjęte w ETAPIE 1](#decyzje-podjęte-w-etapie-1)
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
│   │   ├── game/inventory.ts, combat.ts, progression.ts
│   │   ├── game/data/       # przedmioty, potwory, czary (balans tylko tutaj)
│   │   └── tools/bot.ts     # boty testowe
│   ├── test/                # testy jednostkowe i integracyjne
│   └── Dockerfile
├── client/                  # Godot 4.5 (GDScript)
│   ├── project.godot, export_presets.cfg
│   ├── scripts/autoload/    # Config, Net, GameData, Sprites (grafika), Sfx (dźwięk)
│   ├── scripts/game/        # scena gry, istoty, efekty, loot
│   ├── scripts/ui/          # logowanie, HUD, joystick, plecak, postać
│   ├── scripts/debug/       # automatyczny test klienta
│   └── tools/generate_art.gd  # generator ikony i ekranu startowego
└── tools/build_apk.sh       # budowanie APK (debug / release)
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
| Atak | dotknij potwora (ponownie – przerwij) lub **Atak** (najbliższy / następny) | kliknięcie |
| Leczenie | przycisk **exura** lub wpisz `exura` w czat | – |
| Mikstury | przyciski z czerwoną / niebieską miksturą | – |
| Podnoszenie lootu | dotknij przedmiotu na ziemi (postać podejdzie) | kliknięcie |
| Plecak / ekwipunek | **Plecak** → dotknij przedmiotu → Użyj / Załóż / Zdejmij / Upuść | – |
| Skille, poziom | **Postać** | – |
| Czat | pole na dole; `/online`, `/pomoc` | Enter |

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

## Plan etapów

- [x] **ETAP 1** – grywalne MVP (ten dokument).
- [ ] **ETAP 2** – ekonomia: zbieractwo, crafting, tiery T1–T4, rynek miejski, NPC handlarze, depozyt.
- [ ] **ETAP 3** – PvP: strefy żółta i czerwona, full loot, czaszki, kara za śmierć, błogosławieństwa.
- [ ] **ETAP 4** – gildie, Czarna Strefa (Popielisko), terytoria, bossowie świata, wierzchowce.
- [ ] **ETAP 5** – balans, tutorial, ustawienia grafiki, optymalizacja baterii, ikona i ekran startowy.

## Grafika, dźwięk, licencje

Wszystkie grafiki (kafelki, postacie, potwory, przedmioty, ikona, ekran startowy) i efekty dźwiękowe
są **generowane proceduralnie w kodzie** tego projektu (`client/scripts/autoload/sprites.gd`,
`sfx.gd`, `client/tools/generate_art.gd`) i udostępniane jako **CC0**. Projekt nie zawiera żadnych
assetów z Tibii ani Albion Online. Czcionka: domyślna czcionka Godota (Open Sans, licencja OFL).
