extends Node
## GameManager autoload - holds global game state

# Game time
var time_of_day: float = 0.3  # 0..1 fraction of a 24h day; 0.3 = morning
var day_length_seconds: float = 600.0  # 10 minutes per in-game day

# World reference (set when world is loaded)
var world: Node = null

# Player reference (set when player is spawned)
var player: Node = null

# Game state flags
var paused: bool = false
var game_over: bool = false

signal time_changed(time: float)
signal day_started
signal night_started


func _process(delta: float) -> void:
	if paused or game_over:
		return
	var prev := time_of_day
	time_of_day += delta / day_length_seconds
	if time_of_day >= 1.0:
		time_of_day -= 1.0
	# Emit time change signal (throttled by checking significant change)
	if int(prev * 100) != int(time_of_day * 100):
		time_changed.emit(time_of_day)
	# Day/night transition
	if prev < 0.25 and time_of_day >= 0.25:
		day_started.emit()
	if prev < 0.75 and time_of_day >= 0.75:
		night_started.emit()


func is_day() -> bool:
	return time_of_day >= 0.25 and time_of_day < 0.75


func is_night() -> bool:
	return not is_day()


## Returns 0..1 darkness factor (0 = full day, 1 = full night)
func darkness_factor() -> float:
	# Day: 0.25..0.75 = 0 darkness
	# Night: 0.75..0.25 (wrapping) = 1 darkness
	# Smooth transitions in between
	var t := time_of_day
	if t >= 0.25 and t <= 0.75:
		# Day - small dip at edges
		var edge := 0.05
		if t < 0.25 + edge:
			return 1.0 - (t - 0.25) / edge
		elif t > 0.75 - edge:
			return (t - (0.75 - edge)) / edge
		return 0.0
	else:
		# Night
		var edge := 0.05
		if t < 0.25 - edge or t > 0.75 + edge:
			return 1.0
		# Transition zones
		if t < 0.25:
			return (0.25 - t) / edge
		else:  # t > 0.75
			return (t - 0.75) / edge


func format_time() -> String:
	var hours := int(time_of_day * 24.0)
	var minutes := int((time_of_day * 24.0 - hours) * 60.0)
	return "%02d:%02d" % [hours, minutes]


func reset() -> void:
	time_of_day = 0.3
	world = null
	player = null
	paused = false
	game_over = false
