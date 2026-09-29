# Protokół sieciowy – Popielne Królestwa (wersja 1)

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

## Serwer → klient

| `t` | Pola | Opis |
|-----|------|------|
| `auth_error` | `text` | Błąd logowania/rejestracji. |
| `welcome` | `id`, `name`, `map{w,h,rows}`, `items[]`, `spells[]` | Po zalogowaniu: mapa i definicje danych. |
| `pos` | `x`, `y`, `d` | Autorytatywna pozycja własnej postaci (start, korekta, teleport). |
| `snap` | `e[]`, `g[]` | Stan widocznego obszaru – wysyłany tylko przy zmianie. `e`: istoty `{i,k('p'/'m'),n,x,y,d,h(% HP),l(wygląd),s(czas kroku ms)}`, `g`: przedmioty na ziemi `{i,x,y,it,c}`. |
| `stats` | `hp,mhp,mp,mmp,lvl,exp,expCur,expNext,step,target,skills{nazwa:[poziom,%]}` | Statystyki własnej postaci. |
| `inv` | `bag[]`, `eq{}` | Plecak (20 slotów, `null` = pusty) i ekwipunek. |
| `fx` | `l[]` | Efekty: `num` (liczba obrażeń/leczenia, `c`=`dmg`/`heal`/`mana`), `miss`, `block`, `shot`, `heal`, `death`, `levelup`, `words`, `puff`. |
| `chat` | `from`, `id`, `text`, `x`, `y` | Wiadomość czatu. |
| `sys` | `text` | Komunikat systemowy. |
| `online` | `list[{n,l}]` | Gracze online. |
| `died` | `by`, `lost` | Śmierć postaci. |
| `sfx` | `k` | Dźwięk do odtworzenia. |
| `pong` | `ts` | Odpowiedź na `ping`. |

## Wykrywanie serwera w LAN

Klient wysyła broadcast UDP `PK_DISCOVER` na port **7172**, serwer odpowiada `PK_SERVER <port_ws>`.
