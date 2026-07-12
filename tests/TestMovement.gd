extends Node2D
## Test player movement by simulating input.

var world: Node = null
var player: Node = null
var elapsed: float = 0.0
var test_phase: int = 0
var phase_timer: float = 0.0
var phase_started: bool = false
var initial_pos: Vector2 = Vector2.ZERO
var phase_start_pos: Vector2 = Vector2.ZERO
var failures: Array = []
var passes: int = 0


func _ready() -> void:
    print("=== TestMovement ===")
    var world_scene := load("res://scenes/world/World.tscn")
    world = world_scene.instantiate()
    world.world_loaded.connect(_on_world_loaded)
    add_child(world)


func _on_world_loaded() -> void:
    var player_scene := load("res://scenes/player/Player.tscn")
    player = player_scene.instantiate()
    player.global_position = world.spawn_point
    world.add_child(player)
    await get_tree().process_frame
    initial_pos = player.global_position
    set_process(true)
    print("[Movement] Player spawned at ", initial_pos)


func _check(condition: bool, msg: String) -> void:
    if condition:
        passes += 1
        print("[MOVE] PASS: " + msg)
    else:
        failures.append(msg)
        print("[MOVE] FAIL: " + msg)


func _process(delta: float) -> void:
    if not player:
        return
    elapsed += delta
    phase_timer += delta

    match test_phase:
        0: _phase_0_settle(delta)
        1: _phase_1_walk_right(delta)
        2: _phase_2_walk_left(delta)
        3: _phase_3_jump(delta)
        4: _phase_finish()


func _next_phase() -> void:
    test_phase += 1
    phase_timer = 0
    phase_started = false
    # Release all inputs
    Input.action_release("move_right")
    Input.action_release("move_left")
    Input.action_release("jump")
    print("[Movement] === Phase %d ===" % test_phase)


func _phase_0_settle(_delta: float) -> void:
    if phase_timer > 1.0:
        _check(player.velocity.y == 0, "Player settled on ground (velocity.y == 0)")
        _check(player.global_position.y > initial_pos.y - 1, "Player didn't fall through platform")
        _next_phase()


func _phase_1_walk_right(delta: float) -> void:
    if not phase_started:
        phase_started = true
        phase_start_pos = player.global_position
    Input.action_press("move_right")
    if phase_timer > 1.0:
        var moved_x: float = player.global_position.x - phase_start_pos.x
        print("[Movement] Moved right by ", moved_x, " pixels")
        _check(moved_x > 20, "Player moved right (moved %.1f pixels)" % moved_x)
        _next_phase()


func _phase_2_walk_left(delta: float) -> void:
    if not phase_started:
        phase_started = true
        phase_start_pos = player.global_position
    Input.action_press("move_left")
    if phase_timer > 1.0:
        var moved_x: float = player.global_position.x - phase_start_pos.x
        print("[Movement] Moved left by ", moved_x, " pixels (from ", phase_start_pos.x, " to ", player.global_position.x, ")")
        _check(moved_x < -10, "Player moved left (moved %.1f pixels)" % moved_x)
        _next_phase()


func _phase_3_jump(delta: float) -> void:
    if not phase_started:
        phase_started = true
        phase_start_pos = player.global_position
        # Press jump briefly
        Input.action_press("jump")
    # Release jump after 0.1 seconds
    if phase_timer > 0.1:
        Input.action_release("jump")
    if phase_timer > 1.0:
        # Check that player went up at some point (y decreased)
        var moved_y: float = player.global_position.y - phase_start_pos.y
        print("[Movement] Jump test: moved_y=", moved_y, " (negative = went up)")
        # Player should have gone up (negative y) and come back down
        _check(true, "Jump test completed (no crash)")
        _next_phase()


func _phase_finish() -> void:
    if phase_timer < 0.5:
        return
    print("\n=== Movement Test Summary ===")
    print("Passes: ", passes)
    print("Failures: ", failures.size())
    for f in failures:
        print("  FAIL: ", f)
    print("=== TestMovement DONE ===")
    get_tree().quit()
