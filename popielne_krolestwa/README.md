# POPIELNE KRÓLESTWA

**Wersja 1.0.0: Popielne Królestwa Idle** – mobilna gra RPG idle/clicker (Android, pionowo) zbudowana na świecie,
contencie i grafice MMO Popielnych Królestw. Klikasz potwory krain, zbierasz łup, ulepszasz bohatera i drużynę
najemników, odblokowujesz kolejne regiony, a po Odrodzeniu z Popiołu zaczynasz silniejszy. Gra działa bez
logowania i internetu, a drużyna walczy dalej, gdy nie grasz.

Klasyczne **MMORPG** (klimat Tibii + gospodarka i PvP Albion Online) nadal jest w projekcie – z menu gry
(„Klasyczne MMO”) albo z testów automatycznych; opis poniżej od sekcji „Co działa w ETAPIE 1”.

> Świat został spalony przez upadłego boga Ognia. Gracze to **Popielnicy** – ocaleni, którzy
> odbudowują miasta i walczą o żyzne ziemie.

## Popielne Królestwa Idle (wersja 4.4.0)

**Pętla:** KLIK → ATAK → OBRAŻENIA → ZABICIE → ŁUP → ZŁOTO/XP → ULEPSZENIE → SILNIEJSZY WRÓG → POWTÓRZ.

| System | Jak działa |
|---|---|
| Ekran walki (1.2) | Oprawa „Popiół i żar” wg projektu ekranu: kamienny pasek ZŁOTO / PD / STREFA z plakietkami (żarokryształy, poziom, popiół), portret bohatera z paskami zdrowia i many, nagłówek „[WRÓG - PZ: a / b]” z paskiem w żelaznej ramie, plakietka LVL i pasek etapu (u bossa – czas), duży przycisk **ATAK!** (przytrzymanie = seria), kafle AUTO KLIK (3 ciosy/s przy otwartej grze), 4 czary ze stanem [GOTOWY]/[CD]/[MP] i mikstury, kamienne kafle nawigacji INWENTARZ / TWORZENIE / CZARY / ZADANIA / MAPA / SKLEP (zakładki wysuwają się nad walką). Kamera zza pleców bohatera, potwory przeskalowane do jednej, dużej wysokości. Grafiki: `tools/textures/gen_ui_ash.py` + ikony wycięte z projektu (`assets/ui/ash`). |
| Oprawa 1.3 | Za areną ruiny (wyszczerbione mury z oknami, rozbite wieże, gruz; w Popielisku i Świątyni Ognia – ciemny kamień z żarzącymi się szczelinami) i słupy dymu. Kamienne przyciski, karty i zakładki we wszystkich panelach i w menu głównym. Krytyk rozżarza krawędzie ekranu, ATAK! sypie iskrami. |
| Talenty (menu, 2.0) | 3 gałęzie po 6 węzłów: Wojownik (cios, krytyk, szybkość, obrażenia bossom, Gniew Żarogniewa), Dowódca (DPS najemników, złoto, tańsi najemnicy, XP, Zwiadowcy, Sztandar), Mistyk (mana, siła czarów, krótsze odnowienie, offline, łup, Arcymag). Punkty na stałe: połowa rekordu poziomu + 1 za 5 pięter Wieży; węzeł n wymaga 4·n punktów w gałęzi; pierwszy reset darmowy, potem 100 żarokryształów. |
| Wyprawy (menu, 2.0) | Zwiad 15 min, Patrol 1 h, Wyprawa 4 h, Wielka wyprawa 12 h do dowolnej odkrytej krainy – czas rzeczywisty, także przy zamkniętej grze. Łup: złoto, surowce krainy, skrzynie, żarokryształy, fragmenty wierzchowców. Sloty: 1 + etap 20 + etap 50 + 10. piętro Wieży. Natychmiastowy powrót za żarokryształy. |
| Bestiariusz (menu, 2.0) | 33 gatunki krain; progi 10 / 100 / 1000 / 10 000 zabitych – każdy stopień na stałe +1% obrażeń i +1% złota. |
| Wieża Popiołu (menu, 2.0) | Niekończące się piętra z bossami i elitami wszystkich krain (30 s na piętro, zwycięstwo = od razu wyżej). 3 próby dziennie, kolejne za 40 żarokryształów. Nagrody: żarokryształy za piętro, skrzynia co 5 pięter, punkt talentu za każde 5 pięter rekordu, slot wyprawy za 10. piętro. |
| Runy (menu, 2.1) | 6 rodzajów (Ognia – obrażenia, Krwi – krytyk, Żaru – obrażenia krytyczne, Złota, Mądrości – XP, Wichru – szybkość) × 5 stopni (Okruch … Popielna runa). Po 2 gniazda w każdym slocie ekwipunku (trzecie za 150 żarokryształów) – gniazda zostają przy zmianie przedmiotów i po odrodzeniu. 3 runy łączą się w wyższy stopień za złoto. Źródła: bossowie i elity od etapu 10, Wieża Popiołu, wyprawy 4 h+, skrzynie. Ikony: `tools/textures/gen_runes.py`. |
| Chowańce (menu, 2.2) | 8 gatunków (Lisek Szronek, Wilczek Kieł, Ropuszek, Skarabeusz Złotek, Ogar Popiołu, Bazyliszek Łuska, Niedźwiadek Burek, Smoczek Żarek) w 4 rzadkościach. Jaja: bossowie od etapu 15, co 10 pięter Wieży, długie wyprawy, Boss tygodnia. Kolejne jajo gatunku = gwiazdka (maks. 5), poziom do 10 × gwiazdki za złoto. Aktywny chowaniec chodzi za bohaterem w scenie 3D i daje premię; drugi slot od 25. piętra Wieży. Podgląd 3D w panelu. |
| Boss tygodnia (menu, 2.2) | Co tydzień (od poniedziałku) inny boss regionu o ogromnym zdrowiu; 5 prób dziennie po 30 s, obrażenia sumują się przez tydzień; 6 progów nagród (żarokryształy, skrzynie, runy, jaja). Progi rosną z rekordem etapu. |
| Menu, Rekordy, ocena (3.8) | Menu w sekcjach: Codziennie / Walki i wyzwania / Rozwój bohatera / Kolekcje i inne; tryby jeszcze zablokowane pokazują „🔒 etap N”. Panel Rekordy (etap, poziom, odrodzenia, Wieża, Sen, Arena, lochy, relikwie, bestiariusz, statystyki, czas gry) z przyciskiem „Udostępnij” (tekst + link do Google Play do schowka). Jednorazowa prośba o ocenę (po etapie 30 i 2 h gry, „Później” – ponownie 30 etapów dalej, maks. 2 razy) i przycisk „Oceń grę” w Ustawieniach. |
| Języki (3.9) | Pełne tłumaczenia: angielski, hiszpański, portugalski (BR) i niemiecki (po ~1530 tekstów, sprawdzane symbole %d/%s). Wybór w Ustawieniach (siatka języków) albo automatycznie z języka telefonu. Opisy sklepu i „Nowości” w 5 językach (`docs/google_play`). |
| Ogród Alchemika (4.0) | Od etapu 20: 6 grządek (3 + kolejne na etapach 35/50/70), 5 ziół o czasie wzrostu 10 min–4 h (koszt w złocie), podlewanie −30% czasu, Nawóz Żaru za reklamę (raz dziennie). Zielarstwo do poz. 20 (krótszy wzrost, większy plon, 15% szans na obfity zbiór). Kocioł: 5 eliksirów (obrażenia, złoto, doświadczenie, cios, Smoczy Eliksir) działających jak wzmocnienia. Osiągnięcie „Zielarz”, cel tygodnia, tłumaczenia EN/ES/PT/DE. |
| Złoty Goblin (4.1) | Od etapu 8 zwykły wróg ma 2,5% szans (nie częściej niż co 2 min) zamienić się w Złotego Goblina: ×8 zdrowia, ucieka po 12 s. Nagroda: ×150 złota za wroga, 5–15 żarokryształów, 25% skrzynia lub 12% runa. Złota poświata modelu, licznik czasu, baner, osiągnięcie „Łowca skarbów”, cel tygodnia, wiersze w Rekordach. |
| Mistrzostwo broni (4.2) | Zwycięstwa rozwijają rodzaj trzymanej broni (zwykły wróg 1 PD, elita 5, boss 12, goblin 5); poziomy 0–50 (próg 40·(n+1)^1,6). Premie na poziom: miecze +2% ciosu, topory +3% obrażeń krytycznych, buławy +3% obrażeń bossom, łuki +2% DPS najemników, kostury +2% mocy czarów – działają wszystkie naraz, zostają po odrodzeniu. Panel w „Rozwój bohatera”, osiągnięcie „Mistrz oręża”, wiersz w Rekordach. |
| Smoczy towarzysz (4.3) | Od etapu 45: jajo Żarogniewa (2 h albo 50 żarokr.), smok poz. 1–60 w 4 stadiach (Pisklę, Młody, Dorosły, Pradawny – większy model obok bohatera). Karmienie złotem (20× dziennie) i ziołami z ogrodu (Smocza Papryczka 50 PD). Co 8 s zionięcie: (DPS + cios) × (1,5 + 0,2·poz.), efekt ognia; stałe +1% złota/poz. |
| Twierdza Popielników (4.4) | Od etapu 12: 6 budynków do poz. 30 (Skarbiec +4% złota, Koszary +4% DPS najemników, Kuźnia +3% obrażeń, Biblioteka +4% PD, Wieża Magów +4% mocy czarów, Strażnica +3% offline). Koszt złoto×1,25^poz., czas 2–4 min×1,35^poz. (maks. 8 h), budowa w czasie rzeczywistym. 1 budowniczy (drugi za 300 żarokr.), przyspieszenie 1 żarokr./3 min, reklama −30 min raz dziennie. Osiągnięcie „Budowniczy”, cel tygodnia, Rekordy. |
| Wyzwania tygodnia i Poczta (menu, 3.7) | Co tydzień 7 celów losowanych z puli 12 (te same dla wszystkich w danym tygodniu: bossowie, przeciwnicy, lochy, arena, sen, koło, czary, rzemiosło, ulepszenia, wyprawy, piętra Wieży, krytyki) – nagroda za każdy cel i komplet tygodnia (150 żarokr., Legendarna skrzynia, odłamki, Pieczęć Przebudzenia). Poczta: wiadomości Gildii o nowościach wersji, prezent do powitania i do wiadomości o bieżącej wersji. Kropka przy MENU sumuje też wyzwania, pocztę i darmowy obrót koła. |
| Sen Popielnika (menu, 3.6) | Tryb roguelike od etapu 40. Piętra snu z elitami i bossami krain (co 5. piętro boss), 20 s na piętro; zdrowie zjaw = siła bohatera z początku snu × 0,35 × 1,25^(piętro−1). Po każdym piętrze wybór 1 z 3 błogosławieństw (Ostrze Snu, Wataha Snu, Krwawy Księżyc, Żar w Żyłach, Klepsydra, Kamienna Skóra, Rój Iskier, Sen o Skarbach, Echo Ciosu, Wizja Smoka) – kumulują się do końca snu. Okruchy Snu (2 za piętro + premie za 10/20/30) na Drzewo Snu: Siła Snu (+4% obrażeń/poz.), Złote Sny (+5% złota/poz.), Długi Sen (+1 s/poz.), Jasnowidzenie (błogosławieństwa na start). 1 darmowy sen dziennie, 2 kolejne za 50 żarokr. |
| Przebudzenie najemników (3.5) | Najemnik od poziomu 100 może się przebudzić: każda gwiazdka (maks. 5, kolejne od poz. 200, 300…) to DPS ×3 na zawsze – gwiazdki zostają po odrodzeniu. Koszt: 1, 2, 4, 8, 16 Pieczęci Przebudzenia. Pieczęcie: pełne przejście lochu od poziomu 5, co 10 pięter Wieży, sklep areny (1 dziennie), kram festynu. |
| Festyn Żaru (menu, 3.5) | Wydarzenie w dniach 1–10 każdego miesiąca: Żarne Lampiony z wrogów (zwykli 8%, elity 3, bossowie 4), kram festynu – ekskluzywny strój „Mistrz Festynu” (600), Legendarna skrzynia, jaja, Epickie skrzynie, odłamki, żarokryształy, Pieczęcie Przebudzenia (limity na festyn). Lampiony przechodzą na kolejny festyn; odliczanie w panelu, baner na starcie gry. |
| Klasy bohatera (menu, 3.4) | Od etapu 30: Wojownik (+30% ciosu, +10% krytyka; Furia Żaru – 10 s ciosów ×4, wszystkie krytyczne), Łowca (+40% DPS najemników, +15% złota; Deszcz Strzał – 15 s najemników ×5), Mag (+40% siły czarów, +25% many; Kataklizm – natychmiast 30 s DPS + 30 ciosów i odnowienie czarów). Ciosy (+0,6) i zabójstwa (+3, elity/bossowie więcej) ładują Żar (100); przycisk umiejętności obok ATAK! (pasek Żaru, pulsuje, gdy gotowy). Pierwszy wybór darmowy, zmiana 200 żarokr. |
| Zaklęcia ekwipunku (3.4) | Od etapu 20: zaczarowanie przedmiotu (broń, zbroja) losową premią – obrażenia, złoto, doświadczenie, krytyk, obrażenia krytyczne, szybkość, DPS najemników lub siła czarów – w jakości zwykłej / rzadkiej / epickiej / legendarnej (wartość rośnie z tierem i rzadkością). Przekucie zastępuje zaklęcie (droższe z każdym razem, +1 odłamek relikwii). Zaczarowane przedmioty nie są sprzedawane hurtowo. |
| Kopia zapisu i wibracje (3.4) | Ustawienia → „Kopiuj kod zapisu” / „Wczytaj z kodu”: cały stan gry jako kod `PK1-…` (gzip + base64 + suma kontrolna) – przeniesienie gry na nowy telefon bez konta i serwera. Wibracje przy krytykach, bossach i umiejętnościach (wyłącznik w ustawieniach, uprawnienie VIBRATE). |
| Ścieżka Popielnika (3.3) | 20 celów dla nowych graczy (pierwsze ciosy → najemnicy → czary → rzemiosło → lochy → arena → odrodzenie) z nagrodami. Bieżący cel w złotej karcie na ekranie walki (dotknięcie: odbierz albo przejdź do właściwej zakładki); przy pierwszych 12 celach animowana łapka wskazuje, co nacisnąć. Stare zapisy z dużym postępem zaliczają ścieżkę bez nagród. Zapowiedzi nowych trybów („NOWOŚĆ: …”) przy etapach 15, 25 i pierwszym możliwym odrodzeniu. |
| Koło Żaru (menu, 3.3) | 1 darmowy obrót dziennie, +1 za reklamę, do 5 za 25 żarokr. 8 pól z jawnymi szansami (24/20/14/12/10/10/7/3%) – złoto, żarokryształy, skrzynia, runa, odłamki, wielka wygrana. Koło rysowane w kodzie z animacją obrotu. |
| Wydarzenia i osiągnięcia (3.3) | Nowe tygodnie: Lochów (podwójny łup, +1 klucz) i Gladiatorów (podwójne odznaki, +2 bilety). Osiągnięcia: Grotołaz, Gladiator, Kolekcjoner relikwii. |
| Lochy Żaru (menu, 3.2) | Od etapu 15. Trzy lochy: Skarbiec Goblinów (złoto), Kopalnia Żaru (żarokryształy, runy), Kuźnia Przodków (surowce, skrzynie). 2 klucze dziennie na loch (kolejne wejście 30 żarokr.). 45 s na 10 strażników (ostatni – elita ×3 zdrowia); łup za każdego, pełne przejście daje odłamki relikwii i wyższy poziom. Poziom polecany wg bieżącego etapu. |
| Arena Popiołu (menu, 3.2) | Od etapu 25. Pojedynki z championami rywali (generowanymi wokół rankingu gracza – bez serwera), 30 s na walkę. Ranking ELO (K=32), ligi Brąz → Legenda, 5 biletów dziennie (+ za 25 żarokr.), odznaki chwały za walki, sklep areny (skrzynie, runy, jajo, odłamki, żarokryształy, klucze do lochów, limity dzienne), nagroda tygodnia wg najwyższej ligi, miękki reset rankingu co tydzień. |
| Relikwie (menu, 3.2) | 12 relikwii w 4 zestawach (Dziedzictwo Królów, Oręż Smokobójcy, Sakwy Pielgrzyma, Skarby Szronu). 10 odłamków = losowa relikwia (nowa albo +1 poziom, maks. 10). Premie relikwii i kompletów (+15%, przy poziomach 5+ +40%) wchodzą do statystyk jak runy. Ikony: `tools/textures/gen_mode_icons.py`. |
| Wersja angielska (3.1) | Cała gra po angielsku („Ash Kingdoms”): język wybierany automatycznie wg telefonu (polski → polski, inny → angielski), przełącznik Automatycznie / Polski / English w Ustawieniach. Słownik `data/i18n/en.json` (~1200 wpisów: interfejs, przedmioty, potwory, krainy, czary, zadania, fabuła, sklep). Silnik `scripts/idle/i18n/smart_translation.gd` (własna klasa `Translation`) tłumaczy też napisy składane w kodzie: rozpoznaje wzorce (`"PZ: %s / %s"` → `"HP: %s / %s"`), nazwy ekwipunku (`"Miecz %s"` + stopień), przyrostki `(T3)`, liczniki, ozdobniki i zdania sklejone z kilku części. Test językowy: `-- --idle-shots=KATALOG --lang=en` zapisuje `brak_tlumaczen.txt`. Regulamin i polityka prywatności także po angielsku. |
| Opowieść (2.3) | 8 rozdziałów (`data/idle/story.json`): wstęp przy pierwszym wejściu do krainy, zakończenie po pierwszym pokonaniu jej bossa, epilog przy każdym Kręgu Popiołu. Mówią postacie miast MMO (Kapłanka Wiesława, Mistrz gildii Zawisza, Mistrzyni gildii Jaga, Kapłan Mieczysław…). Tekst pisany na bieżąco, scena czeka, aż ekran jest wolny; wszystko do ponownego przeczytania w menu → Opowieść; wyłącznik w ustawieniach. |
| Przebudzenie Feniksa (menu, 2.3) | Druga warstwa odrodzenia: od 300 Popiołu Dusz zebranego od ostatniego przebudzenia i etapu 80. Zeruje to co odrodzenie oraz Popiół Dusz i Ołtarz; daje Pióra Feniksa na mnożniki (Płomień Feniksa ×obrażenia, Złote Pióra ×złoto, Popiół Odrodzeń, Pamięć Ognia – start dalej, Skrzydła Snu – offline, Mądrość Feniksa – punkty talentów). |
| Żarzący się miecz (2.3) | Broń bohatera w scenie walki płonie (poświata, światło, iskry) – jak na projekcie ekranu. |
| Skarbiec – sklep premium (3.0) | Zakupy Google Play (wtyczka GodotGooglePlayBilling): pakiety żarokryształów (×2 przy pierwszym zakupie), Pakiet Popielnika, Przymierze Żaru (30 dni po 100 żarokryształów), Mieszek Kupca, Złoty Karnet. Przyznawanie po tokenie transakcji (raz), zużywanie/potwierdzanie, przywracanie, zakupy oczekujące. Poza Google Play – wyraźnie oznaczony tryb testowy. Katalog: `data/idle/store.json`. |
| Karnet Popiołu (menu, 3.0) | Sezony po 28 dni, 30 poziomów, ścieżka darmowa i złota (działa wstecz), strój „Popielny Książę” na 30. poziomie. |
| Reklamy z nagrodą (3.0) | Tylko dobrowolne (darmowa skrzynia co 4 h, Zwój Furii ×2 na 5 min, próba w Wieży, ×2 nagroda offline), limit 12/dzień, zgoda RODO (Google UMP); wtyczka godot-admob dodawana w CI, gdy podano identyfikatory AdMob. Mieszek Kupca – nagrody bez reklam. |
| Google Play (3.0) | AAB z Gradle w GitHub Actions (`.github/workflows/popielne_google_play.yml`), target SDK 36, polityka prywatności i regulamin (`/docs/popielne/`, GitHub Pages), ujawnianie szans losowych nagród, jakość grafiki dla słabszych telefonów, gotowe teksty i grafiki sklepu. **Instrukcja krok po kroku: [docs/GOOGLE_PLAY.md](docs/GOOGLE_PLAY.md).** |
| Garderoba (menu, 2.4) | Stroje bohatera z podglądem 3D – sam wygląd, premie zostają z ekwipunku: Strażnik Popielgrodu (etap 10), Łowca Puszczy (15 stopni bestiariusza), Mag Szronogrodu (500 czarów), Rycerz Popiołu (20. piętro Wieży), Pogromca Smoka (Żarogniew), Feniks (przebudzenie). |
| Tygodnie świąteczne (2.4) | Co tydzień inny modyfikator świata: Tydzień Złota (+50% złota), Tydzień Łowów (×2 surowce, +25% łupu), Tydzień Run (×2 runy i jaja), Tydzień Nauki (+50% XP, +25% siły czarów). Informacja przy starcie, na pasku walki i w panelu Bossa tygodnia. |
| Muzyka (2.1) | Trzy pętle syntezowane w całości (`tools/audio/gen_music.py`: lutnia Karplus-Strong, pady, chór, dzwony FM, bębny, pogłos): temat menu, temat walki i temat bossa / Wieży; płynne przejścia, wyłącznik w ustawieniach. |
| Rozmiar (2.0) | Bez limitu rozmiaru: pełna, bezstratna jakość grafik, APK z bibliotekami arm64-v8a i armeabi-v7a (~57 MB). |
| Codzienna nagroda (menu) | Seria 7 dni: złoto, mikstury, żarokryształy, skrzynie; 7. dnia epicka skrzynia i 100 żarokryształów. Opuszczony dzień zaczyna serię od nowa. Okno pojawia się samo przy starcie gry. |
| Osiągnięcia (menu) | 8 osiągnięć po 4–5 stopni (Łowca, Pogromca bossów, Wędrowiec, Weteran, Niezmordowana pięść, Ostrze losu, Adept magii, Feniks); liczą całe dzieje bohatera, także sprzed odrodzeń; nagrody w żarokryształach. Kropka na przycisku MENU pokazuje, co czeka na odbiór. |
| Walka | Dotknij przeciwnika albo przycisku ATAK! (przytrzymanie – 8 ciosów/s). Krytyki, liczby obrażeń, cząsteczki, wstrząs ekranu, dźwięki. Modele 3D bohatera (w założonym ekwipunku), drużyny i potworów z gry MMO na dioramie regionu z pogodą. |
| Najemnicy (DRUŻYNA pod portretem) | 15 najemników ze świata MMO (Strażnik Popielgrodu, Kapłanka Wiesława, Kowal Gerwazy, Mistrz gildii Zawisza, Mag Szronogrodu…) daje DPS; koszt ×1,07 na poziom, kamienie milowe ×2. Trening ciosu zwiększa obrażenia kliknięcia. Zakup ×1 / ×10 / ×100 / MAKS. |
| Regiony (MAPA) | 8 krain po 10 etapów: Łąki Popielgrodu, Puszcza, Moczary, Złote Piaski, Góry Pogorzelne, Szronowe Pustkowia, Popielisko, Świątynia Ognia; potem Kręgi Popiołu. 10 wrogów na etap, na 5. etapie elita, na 10. boss regionu (Herszt Rozbójników, Pradawny Drzewiec, Matka Moczarów, Pustynny Czerw, Władca Gór, Król Szronu, Czempion Popiołu, Żarogniew). |
| Bossowie | Ogromne zdrowie, 30 s na walkę, biją bohatera co 2 s (liczy się zdrowie i obrona z pancerza, mikstury, leczenie). Porażka → farmienie etapu wcześniej, ponowna próba przyciskiem albo sama po 45 s (AUTO). Nagroda: skrzynia, surowce, fragmenty wierzchowców, żarokryształy. |
| Ekwipunek | 6 slotów (głowa, tułów, nogi, stopy, broń, tarcza). Każda rodzina z MMO daje inne premie: miecz – krytyk, topór – obrażenia krytyczne, buława – DPS najemników, łuk – szybkość ataku, kostur – siła czarów i mana, tarcza i płyty – zdrowie i obrona, skóra – złoto, materiał – XP i mana. Rzadkość Zwykły…Legendarny (jakość MMO 1–5). |
| Ulepszanie | Złoto + surowce rodziny (np. miecz: ruda i skóra), koszt rośnie wykładniczo – główny „pochłaniacz” surowców. |
| CRAFT | Rafineria (surowiec → materiał), Kuźnia i Pracownia (ekwipunek T1–T8 z receptur MMO, jakość rośnie z poziomem rzemiosła), Alchemia (mikstury, wzmocnienia z mięsa, kości i trofeów bossów). Receptury odblokowują się z regionami. |
| CZARY | 18 czarów MMO jako umiejętności: Kula ognia (500% + podpalenie), Meteor (5000%, nadmiar przechodzi na kolejnych wrogów), Mroźna nova (zamraża bossa i czas), Przyspieszenie (+100% szybkości), Lodowa zbroja (tarcza), Łańcuch piorunów, Nawałnica, Trujący obłok (% zdrowia bossa), Wyssanie życia… Mana, odnowienie, poziomy ulepszeń, pasek 4 czarów, od etapu 10 rzucanie AUTO. |
| QUESTY | Kronika (22 zadania MMO z trzech miast – aktywują się same, gdy odkryjesz krainę) i 3 odnawiane Zlecenia (pokonaj N wrogów, zdobądź złoto, użyj czarów, ulepsz ekwipunek…). Krótkie cele widać na ekranie walki. |
| Łup i skrzynie | Surowce regionu, łup z tabel bestiariusza MMO, ekwipunek, skrzynie 5 rzadkości, żarokryształy, fragmenty wierzchowców. |
| Wierzchowce (menu → Stajnia) | Koń +10% złota, Łoś +10% XP, Wielbłąd +20% offline, Wilk bojowy +15% obrażeń, Drake +30% obrażeń; ulepszane fragmentami. |
| Sklep i targ (menu) | Mikstury, surowce, ekwipunek, wzmocnienia i skrzynie za żarokryształy; skup; Targ z 6 ofertami kupców trzech miast (odnawiane co 30 min). |
| Offline | Po powrocie: czas × DPS × skuteczność (50% + wielbłąd + Ołtarz), do 12 h (+Ołtarz). Okno „Witaj ponownie!” z animowanymi licznikami. |
| Odrodzenie (menu → Ołtarz Popiołu) | Od etapu 40. Reset etapów, złota, poziomu, najemników, ekwipunku i surowców → Popiół Dusz na stałe ulepszenia (obrażenia, złoto, XP, offline, krytyk, łup, szybkość, start od dalszego etapu). |
| Zapis | Lokalny JSON (user://), zapis co 15 s, przy minimalizacji i wyjściu, suma kontrolna i kopia zapasowa. |

**Balans** (symulacja `tests/balance_sim.tscn`, aktywny gracz): etap ~10 po minucie, ~30 po 10 minutach,
~40 po pół godzinie (pierwsze bariery na bossach regionów), ~50 po godzinie, ~60 po kilku godzinach –
dalej potrzebne są ekwipunek, czary, wierzchowce i odrodzenie.

Analiza projektu 0.9.1 i plan migracji (co zachowano, co zaadaptowano, co zastąpiono): [docs/IDLE_MIGRACJA.md](docs/IDLE_MIGRACJA.md).

Testy wersji idle:
```bash
cd client
godot --headless --path . res://tests/idle_test.tscn            # pętla gry, zapis, offline, prestiż…
godot --headless --path . res://tests/balance_sim.tscn -- --hours=6   # symulacja balansu
godot --path . -- --idle-shots=/tmp/zrzuty                       # zrzuty wszystkich ekranów
node ../tools/export_idle_data.js                                # (po zmianie danych serwera) eksport contentu
```

**Stan MMO: ETAP 4 – wielki świat: trzy miasta, siedem krain, Czarna Strefa, T1–T8, bossowie świata, wierzchowce, gildie i terytoria** (wersja 0.9.1 – magia: 18 czarów w 5 szkołach, zadania z panelem „Aktualne zadania”, kostury) (patrz [Plan etapów](#plan-etapów)).

---

## Spis treści

1. [Co działa w ETAPIE 1](#co-działa-w-etapie-1), [ETAPIE 2](#co-doszło-w-etapie-2--ekonomia), [ETAPIE 3](#co-doszło-w-etapie-3--pvp) i [ETAPIE 4](#co-doszło-w-etapie-4--świat)
2. [Struktura projektu](#struktura-projektu)
3. [Szybki start – tryb „lokalny serwer” (komputer + telefon w tej samej sieci Wi-Fi)](#szybki-start--tryb-lokalny-serwer)
4. [Serwer na VPS (Docker)](#serwer-na-vps-docker)
5. [Ustawienie adresu serwera w kliencie](#ustawienie-adresu-serwera-w-kliencie)
6. [Budowanie i instalacja APK](#budowanie-i-instalacja-apk)
7. [Podpisywanie kluczem release](#podpisywanie-kluczem-release)
8. [Sterowanie](#sterowanie)
9. [Testy](#testy)
10. Decyzje podjęte w [ETAPIE 1](#decyzje-podjęte-w-etapie-1), [ETAPIE 2](#decyzje-podjęte-w-etapie-2), [ETAPIE 3](#decyzje-podjęte-w-etapie-3) i [ETAPIE 4](#decyzje-podjęte-w-etapie-4)
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

## Co doszło w ETAPIE 4 – świat

- **Świat 224×224 pól** (dotąd 96×96) z siedmioma krainami, każda z własnym gruntem, roślinnością, pogodą i potworami:
  - **Łąki Popielgrodu** (południe) – zielone pola, wioski z polami zboża, jeziora; miasto **Popielgród** (rafineria +25%).
  - **Szronowe Pustkowia** (północny zachód) – śnieg, ośnieżone sosny, zamarznięte jeziora, śnieżyca;
    miasto **Szronogród** (kuźnia: zwrot 25% i lepsza jakość).
  - **Złote Piaski** (północny wschód) – wydmy, mesy z warstwowego piaskowca, oazy z palmami, kaktusy, pył;
    miasto **Złotopiask** z kopułami (pracownia: zwrot 25% i lepsza jakość).
  - **Puszcza** (zachód) – gęste, wielkie drzewa, paprocie, grzyby; **Góry Pogorzelne** (północ) – pasma z urwiskami
    i śnieżnymi szczytami; **Moczary** (wschód) – mętne stawy, wierzby, trzciny, nocą świetliki.
  - **Popielisko – Czarna Strefa** (środek) – popiół z żarzącymi się szczelinami, rzeki lawy, obsydianowe iglice,
    **Świątynia Ognia** na wyspie otoczonej fosą lawy z czterema mostami.
- **Drogi** łączą wszystkie miasta i świątynię Popieliska, **rzeki** z mostami, **wioski** (domy, pola w płotach, studnie),
  **ruiny strażnic**, pasma gór wokół świata. Mapa świata: **dotknij minimapy**.
- **Strefy**: zielona wokół miast (T1–T3), żółta (T4–T5), czerwona (T6–T7) pierścieniem wokół Popieliska i w dziczy,
  **czarna** (T8) na Popielisku – full loot jak w czerwonej, plus terytoria gildii.
- **Tiery T5–T8**: nowe surowce (dąb, krwisty buk…, runit, meteoryt, adamantyt, żaryt, bazalt, marmur, obsydian,
  kamień żaru, niebokwiat…, skóry niedźwiedzia, yeti, bazyliszka, smocza), materiały, receptury i ekwipunek do T8.
- **29 rodzajów potworów** w krainach: śnieżne lisy, skarabeusze, ropuchy, skorpiony (trucizna), olbrzymie pająki,
  szronowe wilki, niedźwiedzie, rozbójnicy i ich łucznicy, orkowie i szamani (pociski), mumie, topielce, jaszczuroludzie,
  trolle, yeti, drzewce, kamienne golemy, lodowe zjawy (spowalniające pociski), bazyliszki, żywiołaki ognia,
  popielni rycerze, demony żaru.
- **Bossowie świata** (ogłaszani wszystkim, odradzają się co 30–45 min, wielki łup na ziemi):
  **Król Szronu** (mróz, przywołuje wilki), **Pustynny Czerw** (trzęsienie piasku), **Matka Moczarów** (trucizna,
  przywołuje ropuchy) i **Żarogniew, Popielny Smok** w Świątyni Ognia (fale ognia, żywiołaki; szansa na drake'a).
- **Wierzchowce** (przycisk **Jazda**): koń (+30%), łoś szronowy (+30%, udźwig +250), wielbłąd (+22%, udźwig +500),
  wilk bojowy (+40%), popielny drake (+50%) – kupisz je u **stajennych** (każde miasto ma swoje zwierzęta),
  zsiadasz, gdy walczysz lub oberwiesz.
- **Gildie**: `/gildia załóż Nazwa TAG` (5000 zł, w mieście), `/gildia zaproś Imię`, `/gildia dołącz`, `/gildia opuść`,
  `/gildia wyrzuć Imię`, czat `/g tekst`; skrót [TAG] nad głową, członkowie nie mogą się atakować.
- **Terytoria**: sześć obelisków na Popielisku. Gildia utrzymująca się przy obelisku przez minutę przejmuje go
  (kryształ zmienia kolor na barwę gildii); właściciele mają +25% doświadczenia w pobliżu.
- **Świątynia domowa**: stań na posadzce świątyni dowolnego miasta, a tam się odrodzisz (`/dom`).
- Każde miasto: 9 NPC (bankier, rynek, kupiec, kowal, rzemieślniczka, rafinator, kapłan, **stajenny**, **mistrz gildii**),
  stroje zależne od miasta (futrzane czapy w Szronogrodzie, turbany w Złotopiasku), fontanna, domy.

## Oprawa graficzna – 3D low-poly (Godot 4.5)

Od wersji 0.5.0 świat jest **trójwymiarowy** (styl low-poly, kamera z góry pod kątem jak w Albionie).
Serwer, protokół i mechaniki się nie zmieniły – świat 3D powstaje z tej samej mapy kafelków (1 kafelek = 1 jednostka).

| Element | Jak zrobiony |
|---------|--------------|
| Teren | Siatki generowane w kodzie (`scripts/world3d/world_builder.gd`) w kawałkach 16×16: płaskie cieniowanie, łagodne przejścia kolorów, grunt każdej krainy (łąka, puszcza, śnieg, wydmy, bagno, popiół) z odcieniem strefy, góry z urwiskami i śnieżnymi szczytami, mesy pustyni z warstw piaskowca, zamarznięte jeziora, bruk miast, marmur świątyń z kręgiem run, żarzące się szczeliny Popieliska |
| Woda i lawa | Shader `lowpoly_water.gdshader`: fale, fasetki, piana przy brzegu, mętna woda moczarów; `lowpoly_lava.gdshader`: płynąca, świecąca lawa ze skorupą |
| Obiekty | `world_props.gd`: drzewa każdej krainy (dęby, brzozy, sosny, ośnieżone świerki, palmy, kaktusy, wierzby, wypalone – kołyszą się na wietrze), domy w trzech stylach (szachulec z dachówką, chata z bali pod śniegiem, gliniany dom z kopułą) ze świecącymi oknami, mosty, płoty, pola zboża, studnie, fontanny, ruiny, obeliski, kryształy obsydianu, mury i wieże w stylu miasta, stragany, stacje rzemiosła |
| Postacie | `character_model.gd`: modele z części animowane w kodzie (chód, oddech, cios, strzał z łuku, zbieranie, śmierć, jazda wierzchem). **Wygląd zależy od ekwipunku**: hełm/zbroja/nogi/buty (płyta/skóra/płótno, kolor i materiał tieru T1–T8), miecz/topór/buława/łuk, tarcza okrągła lub migdałowa z herbem. Każdy NPC ma własny strój zależny od miasta |
| Potwory i złoża | 29 potworów i 4 bossów (`creature_models.gd`: pająki, skorpiony, ropuchy, czerw, smok, żywiołaki, drzewce, golemy; humanoidy z kłami, rogami, skrzydłami, ogonami, świecącymi oczami); wierzchowce z siodłami; złoża T1–T8 wyglądają inaczej i maleją w miarę wydobycia |
| Światło | Słońce z cieniami, **cykl dnia i nocy** (zachód słońca, księżyc), pochodnie i kosze ogniowe z migoczącym światłem, gracz niesie światło nocą, poświata (glow) ognia i żaru |
| Atmosfera | Mgła w kolorze krainy i strefy, pogoda: śnieżyca w śniegach, pył na pustyni, świetliki nocą w moczarach i puszczy, popiół i żar na Popielisku |
| Efekty | Krew i iskry przy trafieniu, lecące strzały, słup światła przy awansie i leczeniu, fale umiejętności, gwiazdki ogłuszenia, znacznik dotknięcia |
| Interfejs | Imiona, paski życia i liczby obrażeń jako ostra nakładka 2D; HUD, okna i minimapa w stylu pixel-art (9-patch); ekran logowania ze scenką 3D (ognisko o zmierzchu) |
| Kamera | Płynne podążanie, wstrząs przy trafieniu, **przybliżanie** dwoma palcami / kółkiem myszy |

Dalsze kawałki świata budują się w tle (limit 5 ms na klatkę), zaczynając od najbliższych graczowi.
W menu gry: **„Efekty graficzne: wysokie/niskie”** – wyłącza cienie, poświatę i cząsteczki na słabszych telefonach.

### Grafika 2.0 (wersja 0.7.0) – bardziej realistycznie

| Element | Jak zrobiony |
|---------|--------------|
| Kamera bohatera | Przybliżenie steruje kątem: blisko – kamera nisko za plecami bohatera (widać niebo i horyzont), daleko – widok z góry jak dotąd. Obiekty między kamerą a bohaterem stają się ażurowe |
| Niebo | Shader `sky_world.gdshader`: gradient pory dnia, słońce, księżyc z kraterami, gwiazdy, płynące chmury, niebo zabarwione nastrojem strefy (czerwona/czarna – dymne) |
| Daleki świat | `far_world.gd`: cała mapa w niskiej rozdzielczości (teren, woda, lawa, domy, mury, las) i pierścień wysokich gór za krawędzią świata; nad załadowanymi kawałkami wycinany maską |
| Tekstury | `tools/textures/gen_textures.py` generuje bezszwowe tekstury z mapami normalnych (trawa, ściółka, ziemia, piasek, śnieg, skała, bruk, marmur, błoto, popiół, obsydian, lód, żwir, pole; kora, liście, igły, liście palm, trawa, kamienne bloki, dachówka, deski, tynk). Wynik w `client/assets/textures/` |
| Teren | Shader `terrain.gdshader`: trzy warstwy tekstur na trójkąt mieszane z uwzględnieniem wysokości tekstury (kamienie wystają z trawy), gładkie cieniowanie, rzut trójpłaszczyznowy na zboczach, barwa krainy i strefy |
| Drzewa i trawa | `tree_models.gd`: pnie z teksturą kory, korony z kart liści (dęby, brzozy, wierzby), świerki z gałęzi igieł (też ośnieżone), palmy, kaktusy, martwe drzewa – rysowane jako MultiMesh; kępy trawy kołysane wiatrem |
| Budynki | Mury z kamiennych bloków, dachówka, szachulec z tynkiem i belkami, chaty z bali, skały z teksturą (rzut trójpłaszczyznowy w `lowpoly_object.gdshader`) |
| Postacie | Ludzie (gracze, NPC, bandyci) mają realistyczne proporcje i gładkie kształty: zbroja płytowa z naramiennikami, peleryna od T4, hełmy z przyłbicą i pióropuszem, fryzury, brody |

### Wersja 0.9.0 – magia i zadania

**Magia – 5 szkół, 18 czarów.** Czarów uczą kapłani (słowo „czary”); każde miasto strzeże innych szkół:
Popielgród – Światło i Ogień, Szronogród – Lód i Nekromancja, Złotopiask – Błyskawica i Światło.
Czar rzuca się przyciskiem z paska czarów (4 miejsca, przypinane w Księdze czarów), z Księgi albo formułą na czacie.

| Szkoła | Czary (formuła) |
|--------|-----------------|
| Światło | Leczenie (exura), Wielkie leczenie (exura gran), Krąg światła (exura mas – leczy sojuszników), Oczyszczenie (exana pox), Święty pocisk (exori san – ×2 na nieumarłych) |
| Ogień | Kula ognia (exori flam – podpala), Burza ognia (exevo gran mas flam – obszar), Meteor (exevo flam hur – spada po sekundzie, promień 3) |
| Lód | Lodowy pocisk (exori frigo – spowalnia), Mroźna nova (exevo frigo – zamraża wokół), Lodowa zbroja (utamo frigo – pochłania obrażenia) |
| Błyskawica | Błyskawica (exori vis), Łańcuch piorunów (exori gran vis – przeskakuje na 2 cele), Nawałnica (exevo gran vis hur – pioruny przez 4 s), Przyspieszenie (utani hur) |
| Nekromancja | Wyssanie życia (exori mort – leczy rzucającego), Klątwa (utori mort – +25% obrażeń), Trujący obłok (exevo gran mort) |

Siła czarów rośnie z poziomem i poziomem magii; **kostury T1–T8** (Pracownia) dają +10…+45% siły czarów
i strzelają magicznym pociskiem. Efekty 3D: świecące pociski z ogonem iskier, pioruny, spadający meteor
z wybuchem, lodowe kolce, obłoki, aury (lodowa bańka, złote smugi), błyski oświetlające okolicę nocą.

**Zadania.** Mistrz gildii daje zlecenia łowieckie, rzemieślnik – zbieranie surowców, kapłan – wyprawy
(odwiedź inne miasto, Świątynię Ognia, obelisk; pokonaj bossa). 22 zadania w trzech miastach, część w łańcuchach,
część powtarzalna. Postęp widać w panelu **„Aktualne zadania”** pod portretem.

**Gładkie potwory (0.9.1).** Wszystkie stwory zbudowane z gładkich brył zamiast klocków: pająk z odwłokiem
i ośmioma oczami, skorpion z łukowatym ogonem i kolcem jadowym, metaliczny skarabeusz, ropucha z brodawkami
i wyłupiastymi oczami, Matka Moczarów z grzybami i świecącymi wrzodami, Pustynny Czerw z paszczą pełną zębów,
smok Żarogniew (łuski, rogi, kolce, żarzące się szczeliny, błoniaste skrzydła), żywiołak ognia z płytami lawy,
drzewiec z korzeniami, golem z runami. Orkowie, trolle, jaszczuroludzie, mumie (bandaże), yeti (futro),
demon (skrzydła, ogon z grotem), zjawy (powiewająca szata), szkielety (żebra, czaszka) i Król Szronu mają
realistyczne proporcje jak postacie graczy. Naprawiono błąd klienta przy złożach T5–T8.

### Wersja 0.8.0 – interfejs, przedmioty, zamki, pogoda

| Element | Jak zrobiony |
|---------|--------------|
| Interfejs dark fantasy | `tools/textures/gen_ui.py`: grafitowe panele ze złoconą ramką i ornamentami w rogach, stalowe przyciski, wklęsłe sloty, błyszczące paski życia/many/doświadczenia, okrągła złota obręcz z nitami (portret i minimapa), malowane ikony HUD. Tytuły czcionką szeryfową (DejaVu Serif). HUD: portret z odznaką poziomu, baner krainy („Popielgród – strefa zielona”), zegar świata i pogoda, okrągła minimapa z kierunkiem północy |
| Ikony przedmiotów | `tools/textures/gen_icons.py`: 41 rodzajów × 9 tierów, 96×96, wygładzane; materiały tierów (żelazo, brąz, stal, fiolet, złoto, szkarłat, mithril, obsydian), klejnoty od T4, poświata tła i świecące runy od T6, znaczek tieru cyframi rzymskimi |
| Broń i zbroja 3D | Miecz o przekroju soczewki ze zbroczem, jelcem, głowicą i klejnotem; topór z półksiężycowym ostrzem (od T4 dwusieczny); buława z piórami; łuk refleksyjny; tarcza herbowa. Od T6 runy, T8 – obsydian z ognistą krawędzią i żarzącymi się zdobieniami zbroi. Kolory tierów wspólne z ikonami |
| Podgląd postaci | Okno ekwipunku pokazuje obracający się model 3D postaci w aktualnym ekwipunku |
| Miasta | Cytadela (donżon, cztery okrągłe wieże, blanki, brama, sztandary) i katedra (nawa, przypory, dzwonnica z iglicą, witrażowa rozeta) w każdym mieście, w stylu krainy; pomnik rycerza na fontannie; budowle widać z daleka na horyzoncie |
| Pogoda | Wspólny dla wszystkich cykl co 7 minut: bezchmurnie, deszcz, burza (poza pustynią i Popieliskiem). Deszcz z kroplami, ciemne chmury, mgła, mokra i błyszcząca ziemia z kałużami, pioruny z błyskiem i grzmotem |
| Zwierzęta i wierzchowce | Gładkie bryły zamiast klocków: tułów szerszy w klatce piersiowej, głowa z pyskiem i nosem, kły, stożkowe nogi z kopytami lub łapami, puszyste ogony, szyje koni, siodło z czaprakiem i strzemionami |

Tekstury są generowane algorytmicznie, bo z tego środowiska nie ma dostępu do bibliotek darmowych zasobów
(Poly Haven, Kenney itp.). Każdy plik w `client/assets/textures/` można podmienić lepszym (ten sam rozmiar i układ).

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
│   │   ├── game/systems/    # zbieractwo, ekonomia, PvP, umiejętności, gildie, terytoria
│   │   ├── game/economy/    # księga zleceń rynku, magazyn depozytów
│   │   ├── game/data/       # miasta (szablon), przedmioty T1–T8, receptury, NPC, złoża, potwory i bossowie, czary
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
│   ├── scripts/world3d/     # świat 3D: generator krain (kawałki), obiekty krajobrazu, modele postaci,
│   │                        # stworzeń i bossów, ogień, efekty, loot, nakładka 2D, scenka logowania
│   ├── scripts/ui/          # logowanie, HUD, joystick, plecak, postać, NPC, sklep, depozyt,
│   │                        # rynek, rzemiosło, specjalizacje, minimapa, mapa świata, okno ilości/ceny
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
| Mapa świata | dotknij minimapy (albo Menu → Mapa świata) | kliknięcie minimapy |
| Wierzchowiec | przycisk **Jazda** (wierzchowiec w plecaku) | – |
| Gildia | Menu → Gildia, komendy `/gildia …`, czat `/g tekst` | – |
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
# przegląd krain 3D: --scenario=widoki (Szronogród, Złotopiask, Świątynia Ognia, moczary, puszcza, góry, obelisk, wioska)
# modele stworzeń, bossów i wierzchowców: --scenario=bestiariusz; ekran logowania: --scenario=login
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

## Decyzje podjęte w ETAPIE 4

1. **Mapa 224×224 zamiast 192×192** – przy mniejszej mapie strefy od miast do Popieliska byłyby zbyt ciasne (miasta
   leżałyby niemal przy czarnej strefie). Świat jest nadal generowany deterministycznie z ziarna – każdy start serwera
   daje ten sam świat.
2. **Układ stref**: pierścienie wokół Popieliska (czarna < 30 pól od środka, czerwona < 48, żółta < 58) połączone
   z odległością od miast (zielona do 38 pól, żółta do 64) – wygrywa groźniejsza. Dzięki temu każda kraina ma strefy
   od zielonej po czerwoną, a dzikie krańce świata są niebezpieczne.
3. **Trzy miasta z jednego szablonu 31×25** (NPC, domy, fontanna, świątynia, stacje) – spójna obsługa; wygląd
   (mury, dachy, bruk, stroje NPC) zależy od krainy. Premie: Popielgród – rafineria, Szronogród – kuźnia,
   Złotopiask – pracownia; różne podatki rynku (3%, 4%, 2%).
4. **Czarna Strefa działa jak czerwona** (full loot, bez czaszek) + terytoria i T8; kara za śmierć jak w czerwonej.
5. **Bossowie** stoją w najdalszych czerwonych zakątkach swoich krain, smok w Świątyni Ognia; łup leży na ziemi
   5 minut (walka o łup, jak w Albionie). Czas odrodzenia można skrócić zmienną `BOSS_RESPAWN_SCALE` (testy).
6. **Wierzchowiec trzymany w plecaku** i przełączany przyciskiem (bez nowego slotu ekwipunku) – prościej na telefonie;
   zsiadanie przy walce i trafieniu, nie można wsiąść 5 s po walce.
7. **Gildie przez komendy czatu** (+ mistrz gildii w każdym mieście) i zapis gildii/terytoriów w nowej tabeli
   `world_state` (migracja 4) – bez rozbudowanych okien w tym etapie.
8. **Złoto łączy się w stosy do 10 000** (i waży 0,01 oz) – przy cenach T5–T8 i założeniu gildii 100 sztuk w stosie
   to za mało.
9. **Świątynia domowa** zapisywana w stanie postaci; postacie z poprzedniego świata (inna mapa) są przy pierwszym
   logowaniu przenoszone do świątyni (znacznik wersji mapy).
10. **Wydajność**: siatka zajętości pól dla potworów i „usypianie” potworów dalej niż 22 pola od graczy
    (serwer: ~1 ms na tick przy 20 graczach i ~560 potworach); klient buduje i zwalnia kawałki świata wokół gracza.
11. **Protokół w wersji 3** – nowy świat wymaga aktualizacji klienta i serwera jednocześnie.
12. **Dar bohatera** – postacie z listy `HERO_NAMES` (domyślnie `sazuqe`) przy pierwszym logowaniu dostają jednorazowo wszystkie czary, kostur T8,
    poziom 100, skille walki 90, magię 40, specjalizacje 40, 5 błogosławieństw i komplet arcydzieł T8 (miecz, tarcza,
    zbroja płytowa), zapasowy topór/buławę/łuk T8, narzędzia T8, po 100 wielkich mikstur, Popielnego drake'a
    i 100 000 zł (10 000 w plecaku, reszta w depozycie). Dotychczasowy ekwipunek trafia do plecaka lub depozytu.
    Bohaterom **nic nie wypada po śmierci** (w żadnej strefie, także z czerwoną czaszką). Wersja 3 daru przyznaje
    przedmioty ponownie postaciom, które dostały już wcześniejszy dar.
    Działa na serwerze (zmienna w `docker-compose.yml`) i w trybie offline w przeglądarce.

## Plan etapów

- [x] **ETAP 1** – grywalne MVP.
- [x] **ETAP 2** – ekonomia: zbieractwo, crafting, tiery T1–T4, rynek miejski, NPC handlarze, depozyt.
- [x] **ETAP 3** – PvP: strefy żółta i czerwona, full loot, czaszki, kara za śmierć, błogosławieństwa, umiejętności broni.
- [x] **ETAP 4** – wielki świat (3 miasta, 7 krain), Czarna Strefa, T5–T8, gildie, terytoria, bossowie świata, wierzchowce.
- [ ] **ETAP 5** – balans, tutorial, ustawienia grafiki, optymalizacja baterii, ikona i ekran startowy.

## Grafika, dźwięk, licencje

Wszystkie modele 3D (teren, drzewa, budowle, postacie, potwory), grafiki interfejsu, ikona i efekty dźwiękowe
są **generowane proceduralnie w kodzie** tego projektu (`client/scripts/world3d/`, `client/tools/build_art.gd`,
`client/scripts/autoload/sfx.gd`) i udostępniane jako **CC0**. Projekt nie zawiera żadnych
assetów z Tibii ani Albion Online. Czcionka: domyślna czcionka Godota (Open Sans, licencja OFL).
