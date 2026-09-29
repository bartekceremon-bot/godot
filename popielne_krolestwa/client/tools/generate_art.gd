extends SceneTree
## Generuje ikonę aplikacji i obraz ekranu startowego (pixel art, rysowane w kodzie).
## Uruchomienie: godot --headless --path client --script res://tools/generate_art.gd

const Sprites := preload("res://scripts/autoload/sprites.gd")


func _init() -> void:
	var s := Sprites.new()
	_save(_scaled(_logo(s, 48, true), 4), "res://icon.png")
	_save(_scaled(_logo(s, 108, false), 4), "res://assets/icon_foreground.png")
	_save(_scaled(_background(108), 4), "res://assets/icon_background.png")
	_save(_scaled(_logo(s, 96, false), 4), "res://assets/splash.png")
	s.free()
	print("Grafiki wygenerowane.")
	quit()


func _save(img: Image, path: String) -> void:
	var err := img.save_png(path)
	print(path, " -> ", error_string(err))


func _scaled(img: Image, factor: int) -> Image:
	img.resize(img.get_width() * factor, img.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return img


func _background(size: int) -> Image:
	var c = Sprites.Canvas.new(size, size)
	for y in size:
		var t := float(y) / size
		c.rect(0, y, size, 1, Color(0.18, 0.07, 0.04).lerp(Color(0.05, 0.03, 0.03), t))
	return c.img


## Logo: płonąca korona nad popiołem. with_bg: okrągłe tło (ikona klasyczna).
func _logo(_s, size: int, with_bg: bool) -> Image:
	var c = Sprites.Canvas.new(size, size)
	var k := size / 48.0
	var cx := size / 2.0
	if with_bg:
		c.ellipse(cx, cx, 23 * k, 23 * k, Color("2a120a"))
		c.ellipse(cx, cx, 21 * k, 21 * k, Color("3a1a0e"))
	# Płomienie
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var fx := cx + (i - 3) * 4.2 * k
		var h := (10 + rng.randi_range(0, 7)) * k
		c.ellipse(fx, 20 * k - h * 0.3, 3.2 * k, h * 0.7, Color("e0602a"))
		c.ellipse(fx, 21 * k - h * 0.1, 2.0 * k, h * 0.45, Color("f8c040"))
	# Korona
	var gold := Color("d4a82a")
	c.rect(int(cx - 14 * k), int(24 * k), int(28 * k), int(10 * k), gold)
	for i in 5:
		var px := cx - 14 * k + i * 7 * k
		c.ellipse(px, 23 * k, 2.4 * k, 4 * k, gold)
	c.rect(int(cx - 14 * k), int(31 * k), int(28 * k), int(2 * k), Color("a07a18"))
	for i in 3:
		c.ellipse(cx - 8 * k + i * 8 * k, 28 * k, 1.6 * k, 1.6 * k, Color("c02020"))
	# Popiół pod koroną
	c.ellipse(cx, 38 * k, 17 * k, 4 * k, Color("4a4442"))
	c.ellipse(cx - 6 * k, 37 * k, 5 * k, 2 * k, Color("6a6462"))
	c.outline(Color(0.05, 0.02, 0.02, 1))
	return c.img
