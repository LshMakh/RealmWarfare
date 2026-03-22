class_name FavorManager
extends Node

const SAVE_PATH: String = "user://player_profile.json"

var _upgrades: Dictionary = {}  # upgrade_name -> int (level)
var _discoveries: Dictionary = {}  # discovery_id -> bool
var _personal_bests: Dictionary = {}  # category -> float

const UPGRADE_DEFS: Dictionary = {
	"vitality": {"costs": [50, 100, 200], "max_level": 3},
	"swiftness": {"costs": [50, 100, 200], "max_level": 3},
	"might": {"costs": [75, 150, 300], "max_level": 3},
	"fortune": {"costs": [75, 150, 300], "max_level": 3},
	"quick_draw": {"costs": [100, 200], "max_level": 2},
}


func _ready() -> void:
	load_profile()


func calculate_favor(result: Dictionary) -> Dictionary:
	var breakdown: Dictionary = {}
	var total: int = 0

	# Base participation bonus
	breakdown["base"] = 5
	total += 5

	# Waves survived: +1 per wave (max 20)
	var waves: int = mini(result.get("wave", 0), 20)
	breakdown["waves"] = waves
	total += waves

	# Kills: +1 per 50 kills
	var kills: int = result.get("kills", 0)
	var kill_bonus: int = kills / 50
	breakdown["kills"] = kill_bonus
	total += kill_bonus

	# Boss killed: +20
	var boss_killed: bool = result.get("boss_killed", false)
	if boss_killed:
		breakdown["boss"] = 20
		total += 20

	# Mini-boss kills: +5 each
	var mini_boss_kills: int = result.get("mini_boss_kills", 0)
	if mini_boss_kills > 0:
		var mini_bonus: int = mini_boss_kills * 5
		breakdown["mini_boss"] = mini_bonus
		total += mini_bonus

	# Level reached: +1 per level after level 5
	var level: int = result.get("level", 1)
	var level_bonus: int = maxi(0, level - 5)
	breakdown["level"] = level_bonus
	total += level_bonus

	# First-time discoveries: +10 each
	var new_discoveries: int = result.get("new_discoveries", 0)
	if new_discoveries > 0:
		var discovery_bonus: int = new_discoveries * 10
		breakdown["discoveries"] = discovery_bonus
		total += discovery_bonus

	# Personal best broken: +5
	var personal_bests_broken: int = result.get("personal_bests_broken", 0)
	if personal_bests_broken > 0:
		var pb_bonus: int = personal_bests_broken * 5
		breakdown["personal_bests"] = pb_bonus
		total += pb_bonus

	breakdown["total"] = total
	return breakdown


func get_upgrade_level(upgrade_name: String) -> int:
	return _upgrades.get(upgrade_name, 0) as int


func get_next_upgrade_cost(upgrade_name: String) -> int:
	var level: int = get_upgrade_level(upgrade_name)
	var def: Dictionary = UPGRADE_DEFS.get(upgrade_name, {})
	var costs: Array = def.get("costs", [])
	if level >= costs.size():
		return -1  # Maxed
	return costs[level] as int


func buy_upgrade(upgrade_name: String) -> bool:
	var cost: int = get_next_upgrade_cost(upgrade_name)
	if cost < 0 or GameState.favor < cost:
		return false
	GameState.favor -= cost
	_upgrades[upgrade_name] = get_upgrade_level(upgrade_name) + 1
	save_profile()
	return true


func get_active_bonuses() -> Dictionary:
	var might_level: int = get_upgrade_level("might")
	var fortune_level: int = get_upgrade_level("fortune")
	return {
		"max_hp": get_upgrade_level("vitality") * 10,
		"speed_pct": get_upgrade_level("swiftness") * 5.0,
		"damage_pct": might_level * 5.0 + (5.0 if might_level >= 2 else 0.0),
		"xp_pct": fortune_level * 5.0 + (5.0 if fortune_level >= 2 else 0.0),
		"cooldown_pct": get_upgrade_level("quick_draw") * 10.0,
	}


func get_closest_upgrade() -> Dictionary:
	# Returns the cheapest next upgrade the player can work toward
	var closest: Dictionary = {}
	var min_remaining: int = 999999
	for uname: String in UPGRADE_DEFS:
		var cost: int = get_next_upgrade_cost(uname)
		if cost < 0:
			continue
		var remaining: int = maxi(0, cost - GameState.favor)
		if remaining < min_remaining:
			min_remaining = remaining
			closest = {"name": uname, "cost": cost, "remaining": remaining}
	return closest


# --- Save / Load ---

func save_profile() -> void:
	var data: Dictionary = {
		"favor": GameState.favor,
		"upgrades": _upgrades,
		"discoveries": _discoveries,
		"personal_bests": _personal_bests,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		GameState.favor = int(data.get("favor", 0))
		_upgrades = data.get("upgrades", {})
		_discoveries = data.get("discoveries", {})
		_personal_bests = data.get("personal_bests", {})
