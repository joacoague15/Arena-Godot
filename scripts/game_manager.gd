extends Node

## Sobrevivir la Pampa - Game Manager
## Survival with role-exclusive actions + manual food distribution.
##   CAZAR             (anyone with hunt_yield > 0)
##   FAENAR            (Caudillo – double hunt, becomes weak)
##   CURAR             (Curandera – heals one weak character)
##   RASTREAR          (Vigía – scouts next night's threat)
##   CUIDAR            (any alive – toggled on food screen, +2 hunger next turn)

# --- Constants ---
const NIGHTS_TO_SURVIVE := 10
const STARTING_FOOD := 10
const BASE_EVENT_CHANCE := 0.40
const FOOD_STOLEN_ON_ROBBERY := 3
const EXTRA_FOOD_WHEN_WEAK := 2
const EXTRA_FOOD_WHEN_GUARDED := 2

# --- Enums ---
enum Action { CAZAR, CUIDAR, FAENAR, CURAR, RASTREAR }
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
var scouted_hint: String = ""
var food_allocated: Array = []   # per-character food given by player
var food_produced: Array = []    # per-character food produced by immediate hunt/faena
var guarding: Array = []         # per-character guard toggle (set on food screen)
var cure_target: int = -1        # index of character Curandera will heal
var cure_log_msg: String = ""    # stored log from immediate cure
var hunt_log_msgs: Array[String] = []  # stored logs from immediate hunts

# --- Character ---
class Character:
	var char_name: String
	var food_consumption: int
	var hunt_yield: int
	var guard_reduction: float
	var state: int = 0  # State.NORMAL
	var assigned_action: int = 0  # Action.CAZAR
	var color: Color
	var will_weaken_next_turn: bool = false
	var guarded_last_turn: bool = false

	func is_alive() -> bool:
		return state != 2  # MUERTO

	func is_weak() -> bool:
		return state == 1  # DEBIL

	func get_food_need() -> int:
		if not is_alive():
			return 0
		var need = food_consumption
		if is_weak():
			need += EXTRA_FOOD_WHEN_WEAK
		if guarded_last_turn:
			need += EXTRA_FOOD_WHEN_GUARDED
		return need

	func can_hunt() -> bool:
		return hunt_yield > 0 and is_alive()

	func can_guard() -> bool:
		return guard_reduction > 0.0 and not is_weak() and is_alive()

	func can_faenar() -> bool:
		return char_name == "Caudillo" and is_alive() and not is_weak()

	func can_curar() -> bool:
		return char_name == "Curandera" and is_alive()

	func can_rastrear() -> bool:
		return char_name == "Vigia" and is_alive()

	func weaken_or_kill() -> String:
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
	food_allocated.clear()

	var c1 := Character.new()
	c1.char_name = "Caudillo"
	c1.food_consumption = 3
	c1.hunt_yield = 4
	c1.guard_reduction = 0.35
	c1.color = Color(0.85, 0.30, 0.25)
	characters.append(c1)

	var c2 := Character.new()
	c2.char_name = "Vigia"
	c2.food_consumption = 1
	c2.hunt_yield = 2
	c2.guard_reduction = 0.20
	c2.color = Color(0.25, 0.75, 0.35)
	characters.append(c2)

	var c4 := Character.new()
	c4.char_name = "Curandera"
	c4.food_consumption = 2
	c4.hunt_yield = 1
	c4.guard_reduction = 0.10
	c4.color = Color(0.75, 0.45, 0.85)
	characters.append(c4)

	food_allocated.resize(characters.size())
	food_allocated.fill(0)
	food_produced.resize(characters.size())
	food_produced.fill(0)
	guarding.resize(characters.size())
	guarding.fill(false)


# =========================================
# TURN RESOLUTION (strict order)
# =========================================
# 0. Apply food distribution (player-decided)
# 1. Delayed effects (FAENAR weakness)
# 2. Food consequences (who ate / who didn't)
# 3. Hunting + Faena
# 4. Healing (CURAR)
# 5. Scouting (RASTREAR)
# 6. Security + events
# =========================================

func resolve_turn():
	log_messages.clear()
	_log("--- Noche %d ---" % day)
	_log("")

	# Show scout info from previous turn
	if scouted_hint != "":
		_log("AVISTAMIENTO: %s" % scouted_hint)
		_log("")
		scouted_hint = ""

	_step_delayed_effects()
	_step_food()
	_step_hunting()
	_step_healing()
	_step_scouting()
	_step_security()

	_log("")
	_check_end_conditions()


func _step_delayed_effects():
	for c in characters:
		if not c.is_alive():
			continue
		if c.will_weaken_next_turn:
			c.will_weaken_next_turn = false
			if c.is_alive() and not c.is_weak():
				c.state = State.DEBIL
				_log("%s queda exhausto por la faena anterior." % c.char_name)


func _step_food():
	## Apply player's food distribution and check consequences
	var total_distributed := 0
	for a in food_allocated:
		total_distributed += a
	food -= total_distributed

	for i in range(characters.size()):
		var c = characters[i]
		if not c.is_alive():
			continue
		var need = c.get_food_need()
		var got = food_allocated[i] if i < food_allocated.size() else 0

		if got >= need:
			_log("%s come bien. (%d comida)" % [c.char_name, got])
		else:
			if got > 0:
				_log("%s come poco. (%d/%d necesarios)" % [c.char_name, got, need])
			else:
				_log("%s pasa hambre." % c.char_name)
			var result = c.weaken_or_kill()
			_log(result)

	# Clear guard hunger after food needs are evaluated
	for c in characters:
		c.guarded_last_turn = false
	_log("")


func _step_hunting():
	## Log-only: food was already added immediately when actions were assigned.
	## Also sets will_weaken_next_turn for FAENAR here (during resolution).
	var total_hunted := 0
	for i in range(characters.size()):
		var c = characters[i]
		if not c.is_alive():
			continue
		var produced = food_produced[i] if i < food_produced.size() else 0
		if c.assigned_action == Action.FAENAR:
			if produced > 0:
				total_hunted += produced
				c.will_weaken_next_turn = true
				_log("%s faena con todo: +%d comida. (Quedara exhausto)" % [c.char_name, produced])
			else:
				_log("%s no puede faenar." % c.char_name)
		elif c.assigned_action == Action.CAZAR:
			if produced > 0:
				total_hunted += produced
				_log("%s caza: +%d comida." % [c.char_name, produced])
			else:
				_log("%s no puede cazar." % c.char_name)
	if total_hunted > 0:
		_log("Total cazado: +%d comida." % total_hunted)
	_log("")


func apply_immediate_action(char_idx: int, action: int) -> int:
	## Called from UI when player assigns CAZAR/FAENAR/RASTREAR.
	## Undoes previous action first, then applies new one.
	## Returns food produced (0 for non-hunting actions).
	var c: Character = characters[char_idx]
	_undo_immediate_action(char_idx)
	c.assigned_action = action

	var produced := 0
	if action == Action.CAZAR and c.can_hunt():
		produced = c.hunt_yield
		food += produced
		food_produced[char_idx] = produced
	elif action == Action.FAENAR and c.can_faenar():
		produced = c.hunt_yield * 2
		food += produced
		food_produced[char_idx] = produced
	return produced


func _undo_immediate_action(char_idx: int):
	## Reverses food production from a previous immediate action.
	var prev_produced = food_produced[char_idx]
	if prev_produced > 0:
		food -= prev_produced
		food_produced[char_idx] = 0


func apply_immediate_cure(healer_idx: int, target_idx: int):
	## Called from UI when player picks a cure target. Heals instantly.
	var healer: Character = characters[healer_idx]
	var target: Character = characters[target_idx]
	_undo_immediate_action(healer_idx)
	healer.assigned_action = Action.CURAR
	cure_target = target_idx
	if target.is_alive() and target.is_weak():
		target.state = State.NORMAL
		cure_log_msg = "%s cura a %s. Vuelve a estado normal." % [healer.char_name, target.char_name]
	elif target.is_alive():
		cure_log_msg = "%s trata a %s pero no lo necesita." % [healer.char_name, target.char_name]
	else:
		cure_log_msg = "%s no puede curar a %s." % [healer.char_name, target.char_name]


func _step_healing():
	## Just logs what already happened during the action phase.
	if cure_log_msg != "":
		_log(cure_log_msg)
		cure_log_msg = ""


func _step_scouting():
	for c in characters:
		if not c.is_alive():
			continue
		if c.assigned_action == Action.RASTREAR and c.can_rastrear():
			_log("%s rastreo los alrededores." % c.char_name)
			if randf() < BASE_EVENT_CHANCE:
				if randf() < 0.5:
					scouted_hint = "El Vigia vio huellas de merodeadores. Probable robo."
				else:
					scouted_hint = "El Vigia percibe presencias hostiles. Probable ataque."
			else:
				scouted_hint = "El Vigia no detecto amenazas cercanas."
			_log("(La informacion se revelara al inicio de la proxima noche)")


func _step_security():
	var event_chance := BASE_EVENT_CHANCE

	for i in range(characters.size()):
		var c = characters[i]
		if not c.is_alive():
			continue
		if i < guarding.size() and guarding[i]:
			var reduction = c.guard_reduction
			if c.is_weak():
				reduction *= 0.5
			event_chance -= reduction
			if c.is_weak():
				_log("%s cuida debilitado (-%d%% riesgo)." % [c.char_name, int(reduction * 100)])
			else:
				_log("%s cuida el campamento (-%d%% riesgo)." % [c.char_name, int(reduction * 100)])
			c.guarded_last_turn = true

	event_chance = maxf(0.0, event_chance)
	_log("Riesgo nocturno: %d%%." % int(event_chance * 100))

	if randf() < event_chance:
		_log("")
		_resolve_event()
	else:
		_log("Noche sin incidentes.")
	_log("")


func _resolve_event():
	if randf() < 0.5:
		var stolen := mini(food, FOOD_STOLEN_ON_ROBBERY)
		food -= stolen
		if stolen > 0:
			_log("ROBO: Perdieron %d de comida. Quedan %d." % [stolen, food])
		else:
			_log("ROBO: Intentaron robar pero no habia comida.")
		if randf() < 0.3:
			var victim := _pick_random_alive()
			if victim:
				var result := victim.weaken_or_kill()
				_log("En el forcejeo, %s" % result)
	else:
		var alive: Array = []
		for c in characters:
			if c.is_alive():
				alive.append(c)
		if alive.size() == 0:
			return
		var victim1: Character = alive[randi() % alive.size()]
		var result1 := victim1.weaken_or_kill()
		_log("ATAQUE: %s" % result1)
		if alive.size() > 1 and randf() < 0.35:
			var remaining: Array = []
			for c in alive:
				if c.is_alive() and c != victim1:
					remaining.append(c)
			if remaining.size() > 0:
				var victim2: Character = remaining[randi() % remaining.size()]
				var result2 := victim2.weaken_or_kill()
				_log("ATAQUE: %s" % result2)


func _pick_random_alive() -> Character:
	var alive: Array = []
	for c in characters:
		if c.is_alive():
			alive.append(c)
	if alive.size() == 0:
		return null
	return alive[randi() % alive.size()]


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


func get_guard_reduction_preview() -> float:
	## Returns total event chance reduction from current guarding array.
	var total := 0.0
	for i in range(characters.size()):
		var c = characters[i]
		if not c.is_alive():
			continue
		if i < guarding.size() and guarding[i]:
			var reduction = c.guard_reduction
			if c.is_weak():
				reduction *= 0.5
			total += reduction
	return total


func _log(msg: String):
	log_messages.append(msg)


func restart():
	day = 1
	food = STARTING_FOOD
	game_over = false
	game_won = false
	log_messages.clear()
	scouted_hint = ""
	cure_target = -1
	cure_log_msg = ""
	hunt_log_msgs.clear()
	food_allocated.clear()
	food_produced.clear()
	guarding.clear()
	_init_characters()
