extends Node

## Sobrevivir la Pampa - Game Manager
## Minimal survival: CAZAR / CUIDAR / DORMIR
## Few variables, clear consequences, constant tradeoffs.

# --- Constants ---
const NIGHTS_TO_SURVIVE := 10
const STARTING_FOOD := 10
const BASE_EVENT_CHANCE := 0.40
const FOOD_STOLEN_ON_ROBBERY := 3
const EXTRA_FOOD_WHEN_WEAK := 2

# --- Enums ---
enum Action { CAZAR, CUIDAR, DORMIR }
enum State { NORMAL, DEBIL, MUERTO }

# --- Signals ---
signal turn_resolved
signal game_ended(won: bool)

# --- Game State ---
var day := 1
var food := STARTING_FOOD
var game_over := false
var game_won := false
var log_messages: Array[String] = []

# --- Character ---
class Character:
	var char_name: String
	var food_consumption: int
	var hunt_yield: int
	var guard_reduction: float
	var state: int = 0  # State.NORMAL
	var nights_awake: int = 0
	var assigned_action: int = 2  # Action.DORMIR
	var color: Color

	func is_alive() -> bool:
		return state != 2  # MUERTO

	func is_weak() -> bool:
		return state == 1  # DEBIL

	func get_food_need() -> int:
		if not is_alive():
			return 0
		if is_weak():
			return food_consumption + EXTRA_FOOD_WHEN_WEAK
		return food_consumption

	func can_hunt() -> bool:
		return hunt_yield > 0 and is_alive()

	func can_guard() -> bool:
		return guard_reduction > 0.0 and not is_weak() and is_alive()

	func weaken_or_kill() -> String:
		## Returns description of what happened
		if is_weak():
			state = 2  # MUERTO
			return "%s muere." % char_name
		else:
			state = 1  # DEBIL
			return "%s se debilita." % char_name

var characters: Array = []


func _ready():
	_init_characters()


func _init_characters():
	characters.clear()

	var c1 := Character.new()
	c1.char_name = "Caudillo"
	c1.food_consumption = 3
	c1.hunt_yield = 4
	c1.guard_reduction = 0.35
	c1.color = Color(0.85, 0.30, 0.25)
	characters.append(c1)

	var c2 := Character.new()
	c2.char_name = "Gaucho"
	c2.food_consumption = 2
	c2.hunt_yield = 3
	c2.guard_reduction = 0.20
	c2.color = Color(0.25, 0.55, 0.85)
	characters.append(c2)

	var c3 := Character.new()
	c3.char_name = "Vigia"
	c3.food_consumption = 1
	c3.hunt_yield = 2
	c3.guard_reduction = 0.20
	c3.color = Color(0.25, 0.75, 0.35)
	characters.append(c3)

	var c4 := Character.new()
	c4.char_name = "Curandera"
	c4.food_consumption = 2
	c4.hunt_yield = 0
	c4.guard_reduction = 0.0
	c4.color = Color(0.75, 0.45, 0.85)
	characters.append(c4)


# =========================================
# TURN RESOLUTION (strict order)
# =========================================
# 1. Hunting results
# 2. Security check + event
# 3. Food consumption
# 4. Sleep update
# =========================================

func resolve_turn():
	log_messages.clear()
	_log("--- Noche %d ---" % day)
	_log("")

	# --- Step 1: Hunting ---
	_step_hunting()

	# --- Step 2: Security ---
	_step_security()

	# --- Step 3: Food consumption ---
	_step_food()

	# --- Step 4: Sleep ---
	_step_sleep()

	# --- Check end conditions ---
	_log("")
	_check_end_conditions()


func _step_hunting():
	var total_hunted := 0
	for c in characters:
		if not c.is_alive():
			continue
		if c.assigned_action == Action.CAZAR:
			if c.can_hunt():
				food += c.hunt_yield
				total_hunted += c.hunt_yield
				_log("%s caza: +%d comida." % [c.char_name, c.hunt_yield])
			else:
				_log("%s no puede cazar." % c.char_name)
	if total_hunted > 0:
		_log("Comida total tras la caza: %d." % food)
	_log("")


func _step_security():
	var event_chance := BASE_EVENT_CHANCE
	var guards_active := false

	for c in characters:
		if not c.is_alive():
			continue
		if c.assigned_action == Action.CUIDAR:
			if c.can_guard():
				event_chance -= c.guard_reduction
				guards_active = true
				_log("%s cuida el campamento (-%d%% riesgo)." % [c.char_name, int(c.guard_reduction * 100)])
			elif c.is_weak():
				_log("%s esta debil y no puede cuidar." % c.char_name)
			else:
				_log("%s intenta cuidar pero no es efectivo/a." % c.char_name)

	event_chance = maxf(0.0, event_chance)
	_log("Riesgo nocturno: %d%%." % int(event_chance * 100))

	# Roll for event
	if randf() < event_chance:
		_log("")
		_resolve_event()
	else:
		_log("Noche sin incidentes.")
	_log("")


func _resolve_event():
	# 50/50: robbery or attack
	if randf() < 0.5:
		var stolen := mini(food, FOOD_STOLEN_ON_ROBBERY)
		food -= stolen
		if stolen > 0:
			_log("ROBO: Perdieron %d de comida. Quedan %d." % [stolen, food])
		else:
			_log("ROBO: Intentaron robar pero no habia comida.")
	else:
		var targets: Array = []
		for c in characters:
			if c.is_alive():
				targets.append(c)
		if targets.size() > 0:
			var victim: Character = targets[randi() % targets.size()]
			var result := victim.weaken_or_kill()
			_log("ATAQUE: %s" % result)


func _step_food():
	var total_need := 0
	for c in characters:
		total_need += c.get_food_need()

	if total_need == 0:
		return

	if food >= total_need:
		food -= total_need
		_log("Todos comen. (-%d comida, quedan %d)" % [total_need, food])
	else:
		# Not enough food - everyone eats what's available, one suffers
		food = 0
		var victim := _pick_starvation_victim()
		if victim:
			var result := victim.weaken_or_kill()
			_log("Comida insuficiente! %s" % result)
	_log("")


func _pick_starvation_victim() -> Character:
	# Pick random alive character
	var alive: Array = []
	for c in characters:
		if c.is_alive():
			alive.append(c)
	if alive.size() == 0:
		return null
	return alive[randi() % alive.size()]


func _step_sleep():
	for c in characters:
		if not c.is_alive():
			continue

		if c.assigned_action == Action.DORMIR:
			if c.nights_awake > 0:
				_log("%s duerme (descansa tras %d noche/s despierto/a)." % [c.char_name, c.nights_awake])
			else:
				_log("%s duerme." % c.char_name)
			c.nights_awake = 0
		else:
			c.nights_awake += 1
			if c.nights_awake >= 2:
				var result = c.weaken_or_kill()
				_log("%s lleva 2 noches sin dormir! %s" % [c.char_name, result])
				c.nights_awake = 0  # Reset after penalty
			else:
				_log("%s lleva 1 noche sin dormir." % c.char_name)


func _check_end_conditions():
	var alive_count := 0
	for c in characters:
		if c.is_alive():
			alive_count += 1

	if alive_count == 0:
		game_over = true
		_log("Nadie sobrevivio...")
		game_ended.emit(false)
	elif day >= NIGHTS_TO_SURVIVE:
		game_won = true
		_log("La caravana llego! Sobrevivieron %d noches con %d sobrevivientes." % [day, alive_count])
		game_ended.emit(true)
	else:
		day += 1
		turn_resolved.emit()


func _log(msg: String):
	log_messages.append(msg)


func restart():
	day = 1
	food = STARTING_FOOD
	game_over = false
	game_won = false
	log_messages.clear()
	_init_characters()
