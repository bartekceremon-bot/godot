# Popielne Królestwa – wydanie w Google Play

Ten dokument prowadzi od zera do opublikowanej gry. Część rzeczy musisz zrobić sam
(konto, podpis, płatności, formularze), bo wymagają Twojej tożsamości i dostępu do Google Play Console.

## 0. Co jest już gotowe w projekcie

| Wymóg Google Play | Stan |
|---|---|
| Format **AAB** | GitHub Actions: `.github/workflows/popielne_google_play.yml` (Gradle, AAB + testowe APK) |
| **Target SDK** | 36 (min. 24) – ustawiane w CI (`tools/ci_prepare_play.sh`) |
| **Google Play Billing** | wtyczka GodotGooglePlayBilling dodawana w CI; `scripts/idle/monetization/billing_service.gd` – zakup, zużycie / potwierdzenie, przywracanie, zakupy oczekujące (PENDING nie są przyznawane) |
| Przyznawanie zakupu raz | `PremiumManager.grant()` – po tokenie transakcji (zabezpieczenie przed podwójnym przyznaniem i utratą zakupu po zamknięciu aplikacji) |
| **Ujawnianie szans** losowych nagród | przycisk „Szanse” przy skrzyniach w sklepie i „Szanse wyklucia” u Chowańców |
| **Reklamy** tylko dobrowolne (z nagrodą), limit 12/dzień | `ads_service.gd`; brak banerów i reklam pełnoekranowych bez zgody gracza |
| **Zgoda RODO/UMP** przed reklamami + zmiana zgody | formularz Google UMP; Ustawienia → „Zgoda na reklamy” |
| **Polityka prywatności, regulamin** | `docs/popielne/*.html` w repozytorium (GitHub Pages), linki w Ustawieniach |
| Kontakt dla graczy | Ustawienia → „Kontakt i pomoc” |
| Usunięcie danych | dane tylko na urządzeniu; Ustawienia → „Zacznij od nowa” |
| Działanie na słabych telefonach | Ustawienia → Grafika: Oszczędna / Zwykła / Wysoka |

## 1. Konto i aplikacja w Play Console

1. Załóż konto dewelopera: <https://play.google.com/console/signup> (opłata jednorazowa 25 USD).
   Konto **osobiste** utworzone po 13.11.2023 musi przed publikacją przeprowadzić **test zamknięty: min. 12 testerów przez 14 dni** – zaplanuj to (ścieżka „Test zamknięty”, zaproś znajomych przez e-mail / Grupę Google).
2. Do sprzedaży: **profil płatności** (Konfiguracja → Profil płatności) – dane do wypłat, w UE także dane podatkowe.
3. „Utwórz aplikację”: nazwa **Popielne Królestwa**, język domyślny polski, **Gra**, **Bezpłatna**.
4. Nazwa pakietu w grze: **`pl.popielnekrolestwa.gra`** (ustalona w `client/export_presets.cfg` – nie zmieniaj po pierwszym wydaniu).

## 2. Podpis (klucz przesyłania)

```bash
keytool -genkeypair -v -keystore upload.keystore -alias popielne -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 upload.keystore > upload.keystore.b64
```
Zachowaj plik i hasło w bezpiecznym miejscu (**nie dodawaj do repozytorium**). W GitHubie:
**Settings → Secrets and variables → Actions → New repository secret**:
`ANDROID_KEYSTORE_BASE64` (zawartość .b64), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`popielne`).
W Play Console włącz **Podpisywanie aplikacji przez Google Play** (domyślne) – Google trzyma klucz aplikacji, Ty tylko klucz przesyłania.

## 3. Budowanie AAB

GitHub → **Actions → „Popielne Królestwa – Google Play” → Run workflow**. Po ok. 15 min w zakładce
przebiegu, sekcja **Artifacts**: `PopielneKrolestwa.aab` (do Play Console) i `PopielneKrolestwa.apk`
(do instalacji na telefonie). Numer wersji (version code) = numer przebiegu – rośnie sam.

Opcjonalnie automatyczna wysyłka na ścieżkę testów wewnętrznych: konto usługi Google Cloud z dostępem
do Play Console → sekret `PLAY_SERVICE_ACCOUNT_JSON` → uruchom workflow z zaznaczonym „Wyślij AAB…”.
Pierwsze AAB trzeba wgrać ręcznie.

## 4. Produkty w aplikacji (Zarabianie → Produkty → Produkty w aplikacji)

Utwórz **dokładnie te identyfikatory** (katalog: `client/data/idle/store.json`). Ceny w PLN – Google przeliczy na inne waluty.

| ID produktu | Nazwa | Cena | Typ w grze |
|---|---|---|---|
| `pk_gems_80` | Garść żarokryształów (80) | 4,99 zł | wielokrotny |
| `pk_gems_550` | Sakiewka żarokryształów (550) | 24,99 zł | wielokrotny |
| `pk_gems_1250` | Szkatuła żarokryształów (1250) | 49,99 zł | wielokrotny |
| `pk_gems_2800` | Skrzynia żarokryształów (2800) | 99,99 zł | wielokrotny |
| `pk_gems_8000` | Skarbiec Smoka (8000) | 229,99 zł | wielokrotny |
| `pk_starter` | Pakiet Popielnika | 9,99 zł | jednorazowy |
| `pk_monthly` | Przymierze Żaru (30 dni) | 24,99 zł | wielokrotny |
| `pk_purse` | Mieszek Kupca | 19,99 zł | jednorazowy |
| `pk_season` | Złoty Karnet Popiołu | 39,99 zł | wielokrotny (na sezon) |

Wszystkie jako **produkty jednorazowe (one-time products)** – rodzaj „wielokrotny / jednorazowy” obsługuje gra
(zużywa albo potwierdza zakup). Pierwszy zakup każdego pakietu żarokryształów daje ich ×2.
**Testowanie płatności:** Ustawienia → Testowanie licencji – dodaj swój e-mail; zakupy testowe nie pobierają pieniędzy.

## 5. Reklamy AdMob (opcjonalnie, ale to drugie źródło przychodu)

1. <https://admob.google.com> → dodaj aplikację (Android, po publikacji połącz ze sklepem) → **identyfikator aplikacji** `ca-app-pub-…~…`.
2. Jednostka reklamowa **„Z nagrodą”** → identyfikator `ca-app-pub-…/…`.
3. Prywatność i wiadomości → **komunikat RODO** (UMP) dla EOG/UK – opublikuj.
4. Sekrety GitHub: `ADMOB_APP_ID`, `ADMOB_REWARDED_ID`. Bez nich build nie zawiera reklam (przyciski reklam są ukryte).
5. Plik **app-ads.txt** na stronie wydawcy (GitHub Pages: `docs/popielne/app-ads.txt` – treść podaje AdMob) i adres tej strony w opisie aplikacji w Play.

## 6. Strona z polityką prywatności

Repozytorium → **Settings → Pages → Deploy from a branch → `<gałąź>` / `/docs`**.
Adresy: `https://bartekceremon-bot.github.io/godot/popielne/privacy.html` i `.../terms.html`
(te same są wpisane w grze – `store.json`). **Uzupełnij pola oznaczone [ ]** (dane wydawcy, data).

## 7. Formularze „Treść aplikacji” (App content)

Gotowe odpowiedzi: [`google_play/formularze.md`](google_play/formularze.md) – polityka prywatności, reklamy,
dostęp do aplikacji, klasyfikacja treści (IARC), grupa docelowa, bezpieczeństwo danych, aplikacje rządowe/finansowe/zdrowotne,
identyfikator wyświetlania reklam.

## 8. Wpis w sklepie

Teksty PL/EN: [`google_play/opis_sklepu.md`](google_play/opis_sklepu.md).
Grafiki (gotowe w `docs/google_play/grafiki/`): ikona 512×512, grafika promocyjna 1024×500, zrzuty ekranu telefonu 1080×1920.

## 9. Wydanie

1. Test wewnętrzny (do 100 osób) → sprawdź zakupy testowe i reklamy (w trybie debug – reklamy testowe Google).
2. Test zamknięty (konto osobiste: 12 testerów / 14 dni).
3. Produkcja – stopniowe udostępnianie (np. 20% → 100%).

## 10. Na co uważać (zasady Google Play)

- Nie obiecuj w opisie nagród, których nie ma; nie zachęcaj do klikania w reklamy.
- Szanse losowych nagród muszą być widoczne przed zakupem (są – przycisk „Szanse”).
- Ceny i zawartość pakietów w grze muszą zgadzać się z produktami w Play Console.
- Nie kieruj gry do dzieci (grupa docelowa 13+), bo inaczej obowiązują zasady programu „Dla rodzin” (inne reklamy).
- Zakupy weryfikuje Google Play; gra nie ma własnego serwera – możliwe są zmodyfikowane wersje („piractwo”). Gdy przychody urosną, warto dodać weryfikację zakupów na serwerze (Google Play Developer API).
