# Protokół sieciowy – Popielne Królestwa (wersja 2)

Transport: **WebSocket**, każda wiadomość to obiekt **JSON** z polem `t` (typ).
Serwer jest autorytatywny – klient wysyła wyłącznie intencje.

## Klient → serwer

| `t` | Pola | Opis |
|-----|------|------|
| `register` | `v`, `name`, `pass` | Nowe konto + postać (nazwa konta = nazwa postaci). `v` = wersja protokołu. |
| `login` | `v`, `name`, `pass` | Logowanie. |
| `ping` | `ts` | Pomiar opóźnienia (odpowiedź `pong`). |
| `move` | `d` | Krok: 0=N 1=E 2=S 3=W 4=NE 5=SE 6=SW 7=NW. Za szybki / niemożliwy krok → `pos`. |
| `attack` | `id` | Ustaw cel ataku (0 = przerwij). Atak automatyczny co 2 s. |
| `cast` | `spell` | Rzuć czar (`heal`). |
| `say` | `text` | Czat. Formuła czaru (`exura`) rzuca czar. Komendy: `/online`, `/pomoc`. |
| `pickup` | `id` | Podnieś przedmiot z ziemi (max 1 pole od gracza). |
| `equip` | `slot` | Załóż przedmiot ze slotu plecaka. |
| `unequip` | `slot` | Zdejmij: `head`/`body`/`legs`/`feet`/`weapon`/`shield`. |
| `use` | `slot` | Użyj przedmiotu z plecaka (mikstura, jedzenie). |
| `drop` | `slot`, `count?` | Wyrzuć na ziemię. |
| `who` | – | Lista graczy online (odpowiedź `online`). |
| `gather` | `id` | Zbieraj ze złoża (stojąc obok). Ruch/atak przerywa. |
| `npc` | `id`, `word` | Rozmowa z NPC (słowo kluczowe; puste/„witaj” = powitanie). |
| `close` | – | Zamknięto okno handlu/depozytu/rynku/rzemiosła. |
| `shop_buy` | `item`, `count` | Kup od NPC. |
| `shop_sell` | `slot`, `count` | Sprzedaj NPC z plecaka. |
| `depot_put` | `slot`, `count?` | Odłóż do depozytu miasta. |
| `depot_take` | `index`, `count?` | Weź z depozytu. |
| `market_buy` | `item`, `q`, `price`, `count` | Kup od razu z ofert (cena maksymalna, min. jakość). |
| `market_sell` | `slot`, `price`, `count` | Sprzedaj od razu do zleceń kupna (cena minimalna). |
| `market_order` | `side`=`sell`: `slot`, `price`, `count`; `side`=`buy`: `item`, `q`, `price`, `count` | Nowe zlecenie (najpierw realizowane z istniejącymi). |
| `market_cancel` | `id` | Anuluj zlecenie (zwrot do depozytu). |
| `craft` | `recipe`, `count` | Rafinacja / rzemiosło przy stacji. |

## Serwer → klient

| `t` | Pola | Opis |
|-----|------|------|
| `auth_error` | `text` | Błąd logowania/rejestracji. |
| `welcome` | `id`, `name`, `map{w,h,rows}`, `items[]`, `spells[]`, `recipes[]`, `stations`, `specs[]`, `tierSpecReq[]`, `qualities[]` | Po zalogowaniu: mapa i definicje danych. |
| `pos` | `x`, `y`, `d` | Autorytatywna pozycja własnej postaci (start, korekta, teleport). |
| `snap` | `e[]`, `g[]` | Stan widocznego obszaru – wysyłany tylko przy zmianie. `e`: istoty `{i,k,n,x,y,d,h,l,s}` – `k`: `p` gracz, `m` potwór, `n` NPC, `r` złoże (`h` = % pozostałych jednostek, `l` = `node_<rodzaj>_<tier>`); `g`: przedmioty na ziemi `{i,x,y,it,c,q}`. |
| `stats` | `hp,mhp,mp,mmp,lvl,exp,expCur,expNext,step,target,skills{nazwa:[poziom,%]},cap,weight,specs[[id,poziom,%]],gather` | Statystyki własnej postaci. |
| `inv` | `bag[]`, `eq{}` | Plecak (20 slotów, `null` = pusty) i ekwipunek. Stos: `{item,count,q?}` (q = jakość 1–5). |
| `npc_dialog` | `id`, `name`, `text`, `keywords[]` | Odpowiedź NPC. |
| `shop` | `npc`, `name`, `sells[{item,price}]`, `buys`, `buyRatio` | Okno sklepu NPC. |
| `depot` | `city`, `cityName`, `items[]` | Zawartość depozytu. |
| `market` | `city`, `cityName`, `tax`, `sells[]`, `buys[]`, `mine[]` | Księga zleceń miasta (`{item,q,price,amount}`) i własne zlecenia. |
| `craft_open` | `station`, `name`, `city` | Okno stacji rzemieślniczej (+ opis premii miasta). |
| `fx` | `l[]` | Efekty: `num` (liczba obrażeń/leczenia, `c`=`dmg`/`heal`/`mana`), `miss`, `block`, `shot`, `heal`, `death`, `levelup`, `words`, `puff`, `gather` (`v`, `item`), `craft`. |
| `chat` | `from`, `id`, `text`, `x`, `y` | Wiadomość czatu. |
| `sys` | `text` | Komunikat systemowy. |
| `online` | `list[{n,l}]` | Gracze online. |
| `died` | `by`, `lost` | Śmierć postaci. |
| `sfx` | `k` | Dźwięk do odtworzenia. |
| `pong` | `ts` | Odpowiedź na `ping`. |

## Wykrywanie serwera w LAN

Klient wysyła broadcast UDP `PK_DISCOVER` na port **7172**, serwer odpowiada `PK_SERVER <port_ws>`.
