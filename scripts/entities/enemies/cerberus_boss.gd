class_name CerberusBoss
extends Node
## Cerberus 3-phase boss behavior: The Hunt, The Fury, The Inferno.
## Attached as a child of EnemyBase via _setup_behavior().

enum Phase { HUNT, FURY, INFERNO }
enum Attack { IDLE, TELEGRAPH_BREATH, FIRE_BREATH, TELEGRAPH_CHARGE, CHARGING, TELEGRAPH_TRIPLE, TRIPLE_BREATH }

var _enemy: EnemyBase
var _phase: Phase = Phase.HUNT
var _attack: Attack = Attack.IDLE

# --- Timers ---
var _attack_timer: float = 3.0       # Time until next attack
var _summon_timer: float = 15.0      # Time until next minion summon
var _breath_tick_timer: float = 0.0  # Fire breath damage tick timer
var _breath_duration: float = 0.0    # Remaining breath duration
var _telegraph_timer: float = 0.0    # Telegraph warning duration
var _charge_timer: float = 0.0       # Charge duration
var _charge_direction: Vector2 = Vector2.ZERO
var _inferno_crack_timer: float = 20.0  # Tartarus crack timer (phase 3)

# --- Pools for summoning ---
var _skeleton_pool: ObjectPool = null
var _harpy_pool: ObjectPool = null
var _minotaur_pool: ObjectPool = null
var _crack_pool: ObjectPool = null

# --- EnemyData references for summoning ---
var _skeleton_data: EnemyData = null
var _harpy_data: EnemyData = null
var _minotaur_data: EnemyData = null

# --- Phase-dependent constants ---
const HUNT_SPEED: float = 30.0
const FURY_SPEED: float = 40.0
const INFERNO_SPEED: float = 50.0

const BREATH_RANGE: float = 120.0
const BREATH_DAMAGE: int = 15
const BREATH_TICK_INTERVAL: float = 0.5
const BREATH_DURATION: float = 2.0
const BREATH_COOLDOWN: float = 3.5
const BREATH_ARC_HUNT: float = deg_to_rad(60.0)
const BREATH_ARC_FURY: float = deg_to_rad(75.0)

const TELEGRAPH_BREATH_DURATION: float = 1.0
const TELEGRAPH_CHARGE_DURATION: float = 1.0
const CHARGE_SPEED: float = 200.0
const CHARGE_DURATION: float = 0.7

const SUMMON_INTERVAL: float = 8.0
const SUMMON_SKELETON_COUNT: int = 5
const SUMMON_RADIUS: float = 60.0

const INFERNO_CRACK_INTERVAL: float = 10.0
const INFERNO_CRACK_COUNT: int = 3
const INFERNO_CRACK_RADIUS: float = 100.0

const TELEGRAPH_TINT: Color = Color(1.5, 0.8, 0.3)       # Orange glow for breath telegraph
const CHARGE_TELEGRAPH_TINT: Color = Color(1.4, 0.6, 0.6) # Red tint for charge telegraph
const INFERNO_TINT: Color = Color(1.3, 0.5, 0.5)          # Red body glow for phase 3


func enter() -> void:
	_enemy = get_parent() as EnemyBase
	if not _enemy:
		return
	_phase = Phase.HUNT
	_attack = Attack.IDLE
	_attack_timer = 2.0
	_summon_timer = SUMMON_INTERVAL
	_inferno_crack_timer = INFERNO_CRACK_INTERVAL
	# Connect to health changes for phase transitions
	var health: HealthComponent = _enemy.get_node_or_null("HealthComponent") as HealthComponent
	if health and not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)


func set_pools(skeleton: ObjectPool, harpy: ObjectPool, minotaur: ObjectPool) -> void:
	_skeleton_pool = skeleton
	_harpy_pool = harpy
	_minotaur_pool = minotaur


func set_crack_pool(pool: ObjectPool) -> void:
	_crack_pool = pool


func set_enemy_data(skeleton: EnemyData, harpy: EnemyData, minotaur: EnemyData) -> void:
	_skeleton_data = skeleton
	_harpy_data = harpy
	_minotaur_data = minotaur


# --- Main update ---

func physics_update(delta: float) -> void:
	if not _enemy or _enemy._dying:
		return
	if _enemy.is_stunned():
		return

	var player: Node2D = _enemy.get_player()
	if not player:
		_enemy.velocity = Vector2.ZERO
		return

	# Summon timer (all phases)
	_summon_timer -= delta
	if _summon_timer <= 0.0:
		_summon_timer = SUMMON_INTERVAL
		_summon_minions()

	# Inferno crack timer (phase 3 only)
	if _phase == Phase.INFERNO:
		_inferno_crack_timer -= delta
		if _inferno_crack_timer <= 0.0:
			_inferno_crack_timer = INFERNO_CRACK_INTERVAL
			_spawn_tartarus_cracks(player)

	# Attack state machine
	match _attack:
		Attack.IDLE:
			_do_idle(delta, player)
		Attack.TELEGRAPH_BREATH:
			_do_telegraph_breath(delta)
		Attack.FIRE_BREATH:
			_do_fire_breath(delta, player)
		Attack.TELEGRAPH_CHARGE:
			_do_telegraph_charge(delta)
		Attack.CHARGING:
			_do_charging(delta)
		Attack.TELEGRAPH_TRIPLE:
			_do_telegraph_triple(delta)
		Attack.TRIPLE_BREATH:
			_do_triple_breath(delta, player)


# --- Idle (chase) ---

func _do_idle(delta: float, player: Node2D) -> void:
	_enemy.move_toward_player(_get_phase_speed())

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_choose_next_attack(player)


func _choose_next_attack(player: Node2D) -> void:
	match _phase:
		Phase.HUNT:
			_start_telegraph_breath()
		Phase.FURY:
			if randf() < 0.4:
				_start_telegraph_charge(player)
			else:
				_start_telegraph_breath()
		Phase.INFERNO:
			if randf() < 0.35:
				_start_telegraph_charge(player)
			else:
				_start_telegraph_triple()


# --- Single Breath Telegraph + Attack ---

func _start_telegraph_breath() -> void:
	_attack = Attack.TELEGRAPH_BREATH
	_telegraph_timer = TELEGRAPH_BREATH_DURATION
	_enemy.velocity = Vector2.ZERO
	_enemy.sprite.modulate = TELEGRAPH_TINT


func _do_telegraph_breath(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		_enemy.sprite.modulate = Color.WHITE if _phase != Phase.INFERNO else INFERNO_TINT
		_attack = Attack.FIRE_BREATH
		_breath_duration = BREATH_DURATION
		_breath_tick_timer = 0.0


func _do_fire_breath(delta: float, player: Node2D) -> void:
	_enemy.velocity = Vector2.ZERO
	_breath_duration -= delta
	_breath_tick_timer -= delta

	if _breath_duration <= 0.0:
		_attack = Attack.IDLE
		_attack_timer = BREATH_COOLDOWN
		return

	if _breath_tick_timer <= 0.0:
		_breath_tick_timer = BREATH_TICK_INTERVAL
		var arc: float = BREATH_ARC_FURY if _phase != Phase.HUNT else BREATH_ARC_HUNT
		_apply_cone_damage(player, arc)


# --- Triple Breath Telegraph + Attack (Phase 3) ---

func _start_telegraph_triple() -> void:
	_attack = Attack.TELEGRAPH_TRIPLE
	_telegraph_timer = TELEGRAPH_BREATH_DURATION
	_enemy.velocity = Vector2.ZERO
	_enemy.sprite.modulate = TELEGRAPH_TINT


func _do_telegraph_triple(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		_enemy.sprite.modulate = INFERNO_TINT
		_attack = Attack.TRIPLE_BREATH
		_breath_duration = BREATH_DURATION
		_breath_tick_timer = 0.0


func _do_triple_breath(delta: float, player: Node2D) -> void:
	_enemy.velocity = Vector2.ZERO
	_breath_duration -= delta
	_breath_tick_timer -= delta

	if _breath_duration <= 0.0:
		_attack = Attack.IDLE
		_attack_timer = BREATH_COOLDOWN
		return

	if _breath_tick_timer <= 0.0:
		_breath_tick_timer = BREATH_TICK_INTERVAL
		var dir_to_player: Vector2 = _enemy.global_position.direction_to(player.global_position)
		var base_angle: float = dir_to_player.angle()
		for offset_deg: float in [-45.0, 0.0, 45.0]:
			var cone_dir: Vector2 = Vector2.from_angle(base_angle + deg_to_rad(offset_deg))
			_apply_cone_damage_at_angle(player, cone_dir, BREATH_ARC_FURY)


# --- Charge Telegraph + Attack ---

func _start_telegraph_charge(player: Node2D) -> void:
	_attack = Attack.TELEGRAPH_CHARGE
	_telegraph_timer = TELEGRAPH_CHARGE_DURATION
	_charge_direction = _enemy.global_position.direction_to(player.global_position)
	_enemy.velocity = Vector2.ZERO
	_enemy.sprite.modulate = CHARGE_TELEGRAPH_TINT


func _do_telegraph_charge(delta: float) -> void:
	_enemy.velocity = Vector2.ZERO
	_telegraph_timer -= delta
	if _telegraph_timer <= 0.0:
		_enemy.sprite.modulate = Color.WHITE if _phase != Phase.INFERNO else INFERNO_TINT
		_attack = Attack.CHARGING
		_charge_timer = CHARGE_DURATION


func _do_charging(delta: float) -> void:
	_enemy.velocity = _charge_direction * CHARGE_SPEED
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_enemy.velocity = Vector2.ZERO
		_attack = Attack.IDLE
		_attack_timer = 2.0


# --- Cone Damage Helpers ---

func _apply_cone_damage(player: Node2D, arc: float) -> void:
	var dir_to_player: Vector2 = _enemy.global_position.direction_to(player.global_position)
	_apply_cone_damage_at_angle(player, dir_to_player, arc)


func _apply_cone_damage_at_angle(player: Node2D, cone_direction: Vector2, arc: float) -> void:
	var to_player: Vector2 = player.global_position - _enemy.global_position
	var distance: float = to_player.length()
	if distance > BREATH_RANGE:
		return

	var angle_to_player: float = to_player.angle()
	var cone_angle: float = cone_direction.angle()
	var angle_diff: float = abs(_normalize_angle(angle_to_player - cone_angle))
	if angle_diff <= arc * 0.5:
		var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
		if health:
			health.take_damage(BREATH_DAMAGE)


# --- Phase Transitions ---

func _on_health_changed(new_health: int, max_health: int) -> void:
	if max_health <= 0:
		return
	var pct: float = float(new_health) / float(max_health)
	if pct <= 0.5 and _phase != Phase.INFERNO:
		_enter_phase(Phase.INFERNO)
	elif pct <= 0.75 and _phase == Phase.HUNT:
		_enter_phase(Phase.FURY)


func _enter_phase(new_phase: Phase) -> void:
	_phase = new_phase
	match new_phase:
		Phase.FURY:
			if _enemy.has_node("/root/JuiceManager"):
				_enemy.get_node("/root/JuiceManager").screen_shake(4.0, 0.2)
		Phase.INFERNO:
			_enemy.sprite.modulate = INFERNO_TINT
			if _enemy.has_node("/root/JuiceManager"):
				_enemy.get_node("/root/JuiceManager").screen_shake(6.0, 0.3)
				_enemy.get_node("/root/JuiceManager").hitstop(80)
	# Reset attack so we don't get stuck mid-attack during transition
	_attack = Attack.IDLE
	_attack_timer = 1.0


# --- Summoning ---

func _summon_minions() -> void:
	if not _enemy:
		return
	var player: Node2D = _enemy.get_player()
	if not player:
		return
	var boss_pos: Vector2 = _enemy.global_position

	# Skeletons (all phases)
	if _skeleton_pool and _skeleton_data:
		for i: int in SUMMON_SKELETON_COUNT:
			var skeleton: Node = _skeleton_pool.get_instance()
			if skeleton is EnemyBase:
				var angle: float = (float(i) / float(SUMMON_SKELETON_COUNT)) * TAU
				var offset: Vector2 = Vector2(cos(angle), sin(angle)) * SUMMON_RADIUS
				skeleton.global_position = boss_pos + offset
				skeleton.initialize(_skeleton_data, player)

	# Harpy (phase 2+)
	if _phase != Phase.HUNT and _harpy_pool and _harpy_data:
		var harpy: Node = _harpy_pool.get_instance()
		if harpy is EnemyBase:
			var angle: float = randf() * TAU
			harpy.global_position = boss_pos + Vector2(cos(angle), sin(angle)) * SUMMON_RADIUS
			harpy.initialize(_harpy_data, player)

	# Minotaur (phase 3)
	if _phase == Phase.INFERNO and _minotaur_pool and _minotaur_data:
		var minotaur: Node = _minotaur_pool.get_instance()
		if minotaur is EnemyBase:
			var angle: float = randf() * TAU
			minotaur.global_position = boss_pos + Vector2(cos(angle), sin(angle)) * SUMMON_RADIUS
			minotaur.initialize(_minotaur_data, player)


# --- Tartarus Cracks (phase 3) ---

func _spawn_tartarus_cracks(player: Node2D) -> void:
	if not _crack_pool:
		return
	for i: int in INFERNO_CRACK_COUNT:
		var crack: Node = _crack_pool.get_instance()
		if crack and crack.has_method("initialize"):
			var angle: float = randf() * TAU
			var dist: float = randf_range(30.0, INFERNO_CRACK_RADIUS)
			var offset: Vector2 = Vector2(cos(angle), sin(angle)) * dist
			var spawn_pos: Vector2 = player.global_position + offset
			crack.initialize(spawn_pos)
			GameEvents.hazard_spawned.emit("crack", spawn_pos)


# --- Utility ---

func _normalize_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle


func _get_phase_speed() -> float:
	match _phase:
		Phase.HUNT:
			return HUNT_SPEED
		Phase.FURY:
			return FURY_SPEED
		Phase.INFERNO:
			return INFERNO_SPEED
	return HUNT_SPEED
