class_name Main
extends Node2D
## Main game scene: holds world, player, HUD


func _ready() -> void:
    # Reset game state
    GameManager.reset()
    # Load world
    var world_scene := load("res://scenes/world/World.tscn")
    var world: Node = world_scene.instantiate()
    world.world_loaded.connect(_on_world_loaded)
    add_child(world)


func _on_world_loaded() -> void:
    var world: Node = $World
    # Spawn player
    var player_scene := load("res://scenes/player/Player.tscn")
    var player: Node = player_scene.instantiate()
    player.global_position = world.spawn_point
    world.add_child(player)
    # Add HUD
    var hud_scene := load("res://scenes/ui/HUD.tscn")
    var hud: Node = hud_scene.instantiate()
    add_child(hud)
    print("[Main] Game started")
