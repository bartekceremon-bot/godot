extends Node2D
## Pochodnia / palenisko: sprite (opcjonalny), ogień z cząsteczek i migoczące światło 2D.
## Światło świeci mocniej w nocy (intensywność ustawia game.gd przez `night`).

@export var show_sprite := true
@export var base_energy := 0.9

## 0 = dzień, 1 = pełna noc.
var night := 0.0:
	set(v):
		night = v
		if is_node_ready():
			$Light.visible = night > 0.05 and Config.effects

var _t := randf() * 10.0


func _ready() -> void:
	$Sprite.visible = show_sprite
	if show_sprite:
		$Sprite.texture = Sprites.object_texture("torch")
	$Fire.emitting = Config.effects
	$Light.visible = false


func _process(delta: float) -> void:
	if not $Light.visible:
		return
	_t += delta
	# Migotanie: suma dwóch sinusów o różnych częstotliwościach.
	var flicker := 0.85 + 0.1 * sin(_t * 11.0) + 0.05 * sin(_t * 23.0 + 1.3)
	$Light.energy = base_energy * flicker * night
