class_name IdleGame
extends Node
## GameManager wersji idle/clicker Popielnych Królestw (autoload „Idle”).
## Trzyma stan gry (słownik `s` – zapisywany w całości przez SaveManager), dane (IdleDB)
## i moduły. Moduły komunikują się sygnałami tego węzła (magistrala zdarzeń dla UI).
##
## Pętla: KLIK → ATAK → OBRAŻENIA → ZABICIE → ŁUP → ZŁOTO/XP → ULEPSZENIE → SILNIEJSZY WRÓG.

## Coś się zmieniło (UI odświeża swoje części): "gold", "stats", "inventory", "gear", "quests",
## "spells", "mercs", "mounts", "prestige", "stage", "level", "boosts".
signal changed(what: String)
signal enemy_spawned
## Trafienie wroga: obrażenia, krytyk, źródło ("tap", "auto", "dot", "spell").
signal enemy_hit(amount: float, crit: bool, source: String)
## Zabicie wroga: {name, gold, xp, boss, gems}.
signal enemy_killed(info: Dictionary)
## Łup: lista [id, ilość, rzadkość] (rzadkość 0 dla surowców).
signal loot_gained(items: Array)
signal level_up(level: int)
signal boss_started
signal boss_failed(reason: String)
signal boss_defeated(info: Dictionary)
signal spell_cast(id: String)
signal player_hit(amount: float)
signal toast(text: String, color: Color)
## Nowy tryb gry odblokowany (zapowiedź na ekranie).
signal unlocked(title: String, text: String)

var db := IdleDB.new()
## Stan gry (zapisywany).
var s: Dictionary = {}
var running := false

var stats: PlayerStats
var progression: ProgressionManager
var enemy: EnemyManager
var combat: CombatManager
var inventory: InventoryManager
var equipment: EquipmentManager
var loot: LootManager
var crafting: CraftingManager
var quests: QuestManager
var spells: SpellManager
var mercs: MercenaryManager
var mounts: MountManager
var shop: ShopManager
var market: MarketManager
var prestige: PrestigeManager
var save: SaveManager
var offline: OfflineProgressManager
var audio: AudioManager
var daily: DailyManager
var talents: TalentManager
var bestiary: BestiaryManager
var expeditions: ExpeditionManager
var tower: TowerManager
var runes: RuneManager
var pets: PetManager
var raid: RaidManager
var dungeon: DungeonManager
var arena: ArenaManager
var relics: RelicManager
var path: PathManager
var wheel: WheelManager
var hero: ClassManager
var festival: FestivalManager
var dream: DreamManager
var story: StoryManager
var phoenix: PhoenixManager
var events: EventManager
var skins: SkinManager
var premium: PremiumManager
var season: SeasonManager
## Płatności i reklamy (węzły; na Androidzie – wtyczki Google Play Billing i AdMob).
var billing: BillingService
var ads: AdsService
var achievements: AchievementManager

## Wynik postępu offline z ostatniego uruchomienia (pokazywany w oknie „Witaj ponownie!”).
var offline_report: Dictionary = {}
var _autosave := 0.0
## Mnożnik czasu (testy i symulacja balansu).
var time_scale := 1.0
## Przegląd UI: sceny fabuły tylko na żądanie.
var story_autotest := false


func _ready() -> void:
	db.load_all()
	stats = PlayerStats.new(self)
	progression = ProgressionManager.new(self)
	enemy = EnemyManager.new(self)
	combat = CombatManager.new(self)
	inventory = InventoryManager.new(self)
	equipment = EquipmentManager.new(self)
	loot = LootManager.new(self)
	crafting = CraftingManager.new(self)
	quests = QuestManager.new(self)
	spells = SpellManager.new(self)
	mercs = MercenaryManager.new(self)
	mounts = MountManager.new(self)
	shop = ShopManager.new(self)
	market = MarketManager.new(self)
	prestige = PrestigeManager.new(self)
	save = SaveManager.new(self)
	offline = OfflineProgressManager.new(self)
	audio = AudioManager.new(self)
	daily = DailyManager.new(self)
	talents = TalentManager.new(self)
	bestiary = BestiaryManager.new(self)
	expeditions = ExpeditionManager.new(self)
	tower = TowerManager.new(self)
	runes = RuneManager.new(self)
	pets = PetManager.new(self)
	raid = RaidManager.new(self)
	dungeon = DungeonManager.new(self)
	arena = ArenaManager.new(self)
	relics = RelicManager.new(self)
	path = PathManager.new(self)
	wheel = WheelManager.new(self)
	hero = ClassManager.new(self)
	festival = FestivalManager.new(self)
	dream = DreamManager.new(self)
	story = StoryManager.new(self)
	phoenix = PhoenixManager.new(self)
	events = EventManager.new(self)
	skins = SkinManager.new(self)
	premium = PremiumManager.new(self)
	season = SeasonManager.new(self)
	billing = BillingService.new()
	add_child(billing)
	ads = AdsService.new()
	add_child(ads)
	achievements = AchievementManager.new(self)
	set_process(false)


## Nowy stan gry (pierwsze uruchomienie albo po wyczyszczeniu zapisu).
func new_state() -> Dictionary:
	var now := Time.get_unix_time_from_system()
	return {
		"v": 1, "created": now, "last_time": now, "play_time": 0.0,
		"gold": 0.0, "gems": 0, "ash": 0, "ash_total": 0, "rebirths": 0,
		"level": 1, "xp": 0.0,
		"stage": 1, "max_stage": 1, "kills_in_stage": 0, "farm_mode": false, "auto_progress": true,
		"train_lvl": 0, "mercs": {},
		"inv": {"hp_potion": 3}, "gear": [], "equip": {}, "next_uid": 1,
		"spells": {"heal": 0}, "spell_slots": ["heal", "", "", ""], "auto_spells": {},
		"mounts": {}, "frags": {},
		"quests": {"active": {}, "done": [], "tasks": [], "tasks_done": 0, "track": {}},
		"prestige": {}, "boosts": {}, "craft_xp": 0.0, "craft_lvl": 1,
		"market": {}, "stats": {"kills": 0, "taps": 0, "gold": 0.0, "bosses": 0, "crits": 0, "spells": 0},
		"settings": {"sound": true, "music": true, "story": true, "quality": 2 if not OS.has_feature("mobile") else 1, "auto_potion": true, "effects": true, "lang": "auto"},
		"daily": {"day": 0, "last": ""}, "talents": {}, "bestiary": {}, "exped": {"active": [], "done": 0},
		"tower": {"best": 0, "attempts": 3, "day": ""}, "ach": {"claimed": {}, "best_stage": 1, "best_level": 1},
	}


## Start gry: wczytanie zapisu, postęp offline, pierwszy wróg.
func start() -> void:
	s = save.load_game()
	if s.is_empty():
		s = new_state()
		equipment.give_starter_gear()
	_migrate()
	Config.sound_enabled = bool(s.settings.get("sound", true))
	SmartTranslation.apply_language(str(s.settings.get("lang", "auto")))
	stats.recalc()
	combat.reset_player()
	offline_report = offline.compute_and_apply()
	quests.refresh()
	market.ensure_offers()
	enemy.spawn()
	if int(s.max_stage) == 1:
		story.queue("intro:" + str(progression.region(1).id))
	running = true
	set_process(true)
	changed.emit("all")


## Uzupełnienie brakujących pól starszych zapisów.
func _migrate() -> void:
	var fresh := new_state()
	for k in fresh:
		if not s.has(k):
			s[k] = fresh[k]
	for k in fresh.quests:
		if not s.quests.has(k):
			s.quests[k] = fresh.quests[k]
	for k in fresh.stats:
		if not s.stats.has(k):
			s.stats[k] = fresh.stats[k]


func _process(delta: float) -> void:
	if not running:
		return
	var dt := delta * time_scale
	tick(dt)
	_autosave += delta
	if _autosave >= 15.0:
		_autosave = 0.0
		save.save_game()


## Jeden krok symulacji (używany też przez testy bez okna).
func tick(dt: float) -> void:
	s.play_time = float(s.play_time) + dt
	combat.tick(dt)
	enemy.tick(dt)
	spells.tick(dt)
	progression.tick(dt)
	premium.tick(dt)
	hero.tick(dt)
	stats.tick(dt)


func _exit_tree() -> void:
	SmartTranslation.uninstall()


func _notification(what: int) -> void:
	if not running:
		return
	# Telefon: zapis przy zminimalizowaniu i zamknięciu aplikacji.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save.save_game()


## Aktywne wyzwanie (Wieża, Boss tygodnia, Loch, Arena) albo null – zwykła walka.
func challenge() -> Object:
	for m in [tower, raid, dungeon, arena, dream]:
		if m != null and m.active:
			return m
	return null


func add_gold(n: float) -> void:
	s.gold = float(s.gold) + n
	if n > 0.0:
		s.stats.gold = float(s.stats.gold) + n
		quests.on_event("gold", n)
	changed.emit("gold")


func spend_gold(n: float) -> bool:
	if float(s.gold) + 0.001 < n:
		return false
	s.gold = float(s.gold) - n
	changed.emit("gold")
	return true


func add_gems(n: int) -> void:
	s.gems = int(s.gems) + n
	changed.emit("gold")


func spend_gems(n: int) -> bool:
	if int(s.gems) < n:
		return false
	s.gems = int(s.gems) - n
	changed.emit("gold")
	return true


func notify(text: String, color := Color(0.96, 0.8, 0.48)) -> void:
	toast.emit(text, color)


## Wczytanie stanu z kodu zapisu (przeniesienie gry z innego telefonu).
func import_state(d: Dictionary) -> bool:
	if d.is_empty():
		return false
	tower.active = false
	raid.active = false
	dungeon.active = false
	arena.active = false
	dream.active = false
	s = d
	_migrate()
	if s.gear.is_empty():
		equipment.give_starter_gear()
	stats.recalc()
	combat.reset_player()
	quests.refresh()
	market.ensure_offers()
	enemy.spawn()
	save.save_game()
	changed.emit("all")
	return true


## Wyczyszczenie całej gry (ustawienia – „Zacznij od nowa”).
func wipe() -> void:
	save.delete_save()
	s = new_state()
	equipment.give_starter_gear()
	stats.recalc()
	combat.reset_player()
	quests.refresh()
	market.ensure_offers()
	enemy.spawn()
	save.save_game()
	changed.emit("all")
