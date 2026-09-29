extends SceneTree
## Generator grafik interfejsu (pixel art: ikony przedmiotów, ramki, przyciski, ikona aplikacji)
## -> PNG w res://assets/ + indeks res://assets/atlas_index.json. Świat i postacie są modelami 3D
## tworzonymi w kodzie gry (scripts/world3d/).
## Uruchomienie: tools/build_assets.sh (albo: godot --headless --path client --script res://tools/build_art.gd)
##
## Wszystkie grafiki są tworzone przez ten kod (licencja CC0). Każdy PNG można podmienić
## ręcznie narysowaną wersją – gra czyta tylko pliki i indeks.

const OUT := "res://assets/"
var index := {}


func _init() -> void:
	var t0 := Time.get_ticks_msec()
	for d in ["items", "ui", "fx"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + d))
	_items()
	_ui()
	var f := FileAccess.open(OUT + "atlas_index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(index, "\t"))
	f.close()
	print("Grafiki wygenerowane w %d ms." % (Time.get_ticks_msec() - t0))
	quit()


## Powiększenie pikseli (nearest) – interfejs w 2x wygląda wyraźnie na telefonie.
func _x2(img: Image, f: int = 2) -> Image:
	img.resize(img.get_width() * f, img.get_height() * f, Image.INTERPOLATE_NEAREST)
	return img


func _save(img: Image, path: String) -> void:
	var err := img.save_png(OUT + path)
	if err != OK:
		push_error("Zapis %s: %s" % [path, error_string(err)])


# ---------------------------------------------------------------------------

func _items() -> void:
	var names: Array = ArtItems.ICONS
	var atlas := Image.create(5 * 32, names.size() * 32, false, Image.FORMAT_RGBA8)
	var items := {}
	for i in names.size():
		for t in 5:
			atlas.blit_rect(ArtItems.icon(names[i], t), Rect2i(0, 0, 32, 32), Vector2i(t * 32, i * 32))
			items["%s_%d" % [names[i], t]] = [t * 32, i * 32]
	_save(atlas, "items/items.png")
	index["items"] = items


func _ui() -> void:
	_save(_x2(ArtUI.panel()), "ui/panel.png")
	for s in ["normal", "hover", "pressed", "disabled"]:
		_save(_x2(ArtUI.button(s)), "ui/button_%s.png" % s)
	_save(_x2(ArtUI.slot()), "ui/slot.png")
	for b in ["hp", "mp", "exp", "bg"]:
		_save(_x2(ArtUI.bar(b)), "ui/bar_%s.png" % b)
	# Ikona aplikacji, ikona adaptacyjna Androida i ekran startowy.
	_save(_x2(ArtUI.logo(48, true), 4), "../icon.png")
	_save(_x2(ArtUI.logo(108, false), 4), "icon_foreground.png")
	_save(_x2(ArtUI.icon_background(108), 4), "icon_background.png")
	_save(_x2(ArtUI.logo(96, false), 4), "splash.png")
	_save(ArtUI.joystick_base(), "ui/joystick_base.png")
	_save(ArtUI.joystick_knob(), "ui/joystick_knob.png")
	for n in ["bag", "character", "specs", "people", "menu", "chat", "attack", "heal", "skull_white", "skull_red"]:
		_save(ArtUI.icon(n), "ui/icon_%s.png" % n)
	_save(ArtUI.soft_dot(16), "fx/soft_dot.png")
	_save(ArtUI.soft_dot(64), "fx/soft_light.png")
