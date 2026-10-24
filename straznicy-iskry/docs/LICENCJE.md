# Licencje i źródła materiałów

| Element | Źródło | Licencja |
|---|---|---|
| Kod gry (GDScript, shadery, HTML) | napisany dla projektu | własność zamawiającego (AI Bliżej) |
| Grafika: postacie, BLIK, przeciwnicy, wyspy, rekwizyty, ikony, efekty | rysowana kodem w `scripts/fx/art.gd`, `scripts/world/*`, `scripts/ui/icons.gd` — bez zewnętrznych obrazków | jak kod gry |
| Ikona gry (`godot/icon.svg`), grafika loadera w `web/shell.html` | wykonane dla projektu (SVG) | jak kod gry |
| Efekty dźwiękowe i muzyka (`godot/assets/audio`) | wygenerowane syntezatorem `tools/generate_audio.py` (sinusy, szum, obwiednie) — bez cudzych nagrań i sampli | jak kod gry |
| Czcionka **Nunito** | Google Fonts, The Nunito Project Authors | SIL Open Font License 1.1 — `godot/assets/fonts/OFL-Nunito.txt` |
| Czcionka **Cinzel** | Google Fonts, The Cinzel Project Authors | SIL Open Font License 1.1 — `godot/assets/fonts/OFL-Cinzel.txt` |
| **Godot Engine** 4.7.2 (silnik i szablony eksportu Web wbudowane w `index.wasm`/`index.js`) | godotengine.org | MIT — © Godot Engine contributors, Juan Linietsky, Ariel Manzur; wraz z bibliotekami firm trzecich wymienionymi w <https://godotengine.org/license> |

Uwagi:
- Nie pobrano żadnych cudzych postaci, sprite'ów, tekstur, muzyki ani efektów dźwiękowych.
- Do generowania i testów użyto narzędzi, które **nie trafiają** do gry: Python, numpy, ffmpeg (libvorbis), Playwright + Chromium.
- Licencja MIT Godota wymaga zachowania informacji o prawach autorskich przy dystrybucji silnika — zamieszczono ją w tym pliku i w ekranie „O grze”.
- Nazwa i znak „AI Bliżej” należą do zamawiającego.
