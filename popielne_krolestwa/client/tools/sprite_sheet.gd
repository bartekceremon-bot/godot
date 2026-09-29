extends SceneTree
## Arkusz podglądowy wszystkich grafik (ikony T1–T4, złoża, istoty) – do przeglądu wyglądu.
## Uruchomienie: godot --headless --path client --script res://tools/sprite_sheet.gd -- /sciezka/wynik.png

const SpritesScript := preload("res://scripts/autoload/sprites.gd")

const ICONS := ["wood", "stone", "ore", "fiber", "hide", "planks", "blocks", "bars", "cloth", "leather",
	"sword", "axe", "club", "bow", "shield", "woodaxe", "pickaxe", "sickle",
	"plate_head", "plate_body", "plate_legs", "plate_feet", "leather_head", "leather_body",
	"leather_legs", "leather_feet", "cloth_head", "cloth_body", "cloth_legs", "cloth_feet"]
const CREATURES := ["rat", "boar", "wolf", "hound", "skeleton", 0, 3, "npc_banker", "npc_market",
	"npc_trader", "npc_smith", "npc_crafter", "npc_refiner"]


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://sheet.png"
	var s = SpritesScript.new()
	var cols := ICONS.size()
	var img := Image.create(cols * 34, 11 * 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.45, 0.25))
	for t in range(1, 5):
		for i in ICONS.size():
			img.blend_rect(s.item_icon(ICONS[i], t).get_image(), Rect2i(0, 0, 32, 32), Vector2i(i * 34, (t - 1) * 34))
	var kinds := ["wood", "stone", "ore", "fiber"]
	for k in kinds.size():
		for t in range(1, 5):
			img.blend_rect(s.creature("node_%s_%d" % [kinds[k], t], 2, 0).get_image(), Rect2i(0, 0, 32, 32), Vector2i((k * 4 + t - 1) * 34, 4 * 34))
	for i in CREATURES.size():
		img.blend_rect(s.creature(CREATURES[i], 1, 0).get_image(), Rect2i(0, 0, 32, 32), Vector2i(i * 34, 5 * 34))
		img.blend_rect(s.creature(CREATURES[i], 2, 1).get_image(), Rect2i(0, 0, 32, 32), Vector2i(i * 34, 6 * 34))
	for k in "MKWPD".length():
		img.blit_rect(s.draw_tile("MKWPD"[k], 0), Rect2i(0, 0, 32, 32), Vector2i(k * 34, 7 * 34))
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	s.free()
	print("zapisano ", out)
	quit()
