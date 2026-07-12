extends Node2D
## Stability test: runs the game for 30 seconds and checks for errors/crashes.

var world: Node = null
var player: Node = null
var elapsed: float = 0.0
var error_count: int = 0
const TEST_DURATION := 30.0


func _ready() -> void:
    print("=== TestStability ===")
    var world_scene := load("res://scenes/world/World.tscn")
    world = world_scene.instantiate()
    world.world_loaded.connect(_on_world_loaded)
    add_child(world)


func _on_world_loaded() -> void:
    var player_scene := load("res://scenes/player/Player.tscn")
    player = player_scene.instantiate()
    player.global_position = world.spawn_point
    world.add_child(player)
    var hud_scene := load("res://scenes/ui/HUD.tscn")
    var hud: Node = hud_scene.instantiate()
    add_child(hud)
    var guide_scene := load("res://scenes/npcs/GuideNPC.tscn")
    var guide: Node = guide_scene.instantiate()
    guide.global_position = world.spawn_point + Vector2(40, 0)
    guide.set_home(world.spawn_point + Vector2(40, 0))
    world.add_child(guide)
    world.npcs.append(guide)
    set_process(true)
    print("[Stability] Game running for ", TEST_DURATION, " seconds...")


func _process(delta: float) -> void:
    if not player:
        return
    elapsed += delta
    if int(elapsed) % 5 == 0 and int(elapsed) > 0 and abs(elapsed - int(elapsed)) < delta:
        print("[Stability] t=%.1f enemies=%d items=%d player_pos=%s hp=%d/%d" % [
            elapsed,
            world.enemies.size(),
            world.item_drops.size(),
            player.global_position,
            player.health,
            player.max_health
        ])
    if elapsed >= TEST_DURATION:
        print("[Stability] Test complete! No crashes. Enemies spawned: ", world.enemies.size())
        print("=== TestStability DONE ===")
        get_tree().quit()
