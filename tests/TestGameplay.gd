extends Node2D
## Comprehensive gameplay simulation test.
## Drives the player through key actions: mining, placing, crafting, combat, boss.

var world: Node = null
var player: Node = null
var hud: Node = null
var test_phase: int = -1
var test_timer: float = 0.0
var phase_in_progress: bool = false
var failures: Array = []
var passes: int = 0


func _ready() -> void:
    print("=== TestGameplay ===")
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
    hud = hud_scene.instantiate()
    add_child(hud)
    await get_tree().process_frame
    test_phase = 0
    set_process(true)
    _log("World loaded, player spawned at " + str(player.global_position))


func _log(msg: String) -> void:
    print("[TEST] " + msg)


func _check(condition: bool, msg: String) -> void:
    if condition:
        passes += 1
        _log("PASS: " + msg)
    else:
        failures.append(msg)
        _log("FAIL: " + msg)


func _next_phase() -> void:
    test_phase += 1
    test_timer = 0
    phase_in_progress = false
    _log("=== Phase " + str(test_phase) + " ===")


func _process(delta: float) -> void:
    if test_phase < 0 or not player:
        return
    if phase_in_progress:
        return
    test_timer += delta
    match test_phase:
        0: _phase_0_wait_for_settle()
        1: _phase_1_test_mining()
        2: _phase_2_test_placing()
        3: _phase_3_test_inventory()
        4: _phase_4_test_crafting()
        5: _phase_5_test_combat()
        6: _phase_6_test_boss_summon()
        7: _phase_7_test_boss_combat()
        8: _phase_finish()


func _phase_0_wait_for_settle() -> void:
    if test_timer < 1.0:
        return
    phase_in_progress = true
    _check(player.health == 100, "Player starts with 100 HP")
    _check(player.max_health == 100, "Player max HP is 100")
    _check(player.inventory.size() == 40, "Inventory has 40 slots")
    var has_pickaxe := false
    for slot in player.inventory:
        if slot and typeof(slot) == TYPE_DICTIONARY and slot.get("id") == "copper_pickaxe":
            has_pickaxe = true
            break
    _check(has_pickaxe, "Player has copper pickaxe")
    _check(player.count_item("copper_axe") == 1, "Player has copper axe")
    _check(player.count_item("copper_sword") == 1, "Player has copper sword")
    _check(player.count_item("torch") == 10, "Player has 10 torches")
    _next_phase()


func _phase_1_test_mining() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    # Find a dirt tile to mine
    var pt := WorldData.world_to_tile_pos(player.global_position)
    var target := Vector2i(pt.x, pt.y + 5)
    for dy in range(1, 20):
        var t: int = world.get_tile(pt.x, pt.y + dy)
        if t != WorldData.Tile.AIR:
            target = Vector2i(pt.x, pt.y + dy)
            break
    var old_tile: int = world.get_tile(target.x, target.y)
    _log("Mining tile at " + str(target) + " (was " + str(old_tile) + ")")
    var drops_before: int = world.item_drops.size()
    player._break_tile(target.x, target.y, old_tile)
    var new_tile: int = world.get_tile(target.x, target.y)
    _check(new_tile == WorldData.Tile.AIR, "Tile was mined (now AIR)")
    # Wait a frame for item drop to spawn
    await get_tree().process_frame
    _check(world.item_drops.size() > drops_before, "Item drop spawned after mining")
    _next_phase()


func _phase_2_test_placing() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    player._add_item("dirt", 5)
    var dirt_count_before: int = player.count_item("dirt")
    _log("Dirt count before placing: " + str(dirt_count_before))
    var pt := WorldData.world_to_tile_pos(player.global_position)
    var target := Vector2i(pt.x + 2, pt.y - 2)
    if world.get_tile(target.x, target.y) != WorldData.Tile.AIR:
        target = Vector2i(pt.x + 3, pt.y - 3)
    # Set wall behind so we can place
    world.set_wall(target.x, target.y, WorldData.Tile.DIRT)
    # Place dirt block
    var item_data: Dictionary = ItemDB.get_item("dirt")
    player._do_placing(target, item_data)
    await get_tree().process_frame
    var new_tile: int = world.get_tile(target.x, target.y)
    _check(new_tile == WorldData.Tile.DIRT, "Dirt block was placed")
    var dirt_count_after: int = player.count_item("dirt")
    _log("Dirt count after placing: " + str(dirt_count_after))
    _check(dirt_count_after == dirt_count_before - 1, "Dirt count decreased by 1")
    _next_phase()


func _phase_3_test_inventory() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    var before_wood: int = player.count_item("wood")
    player._add_item("wood", 10)
    var after_wood: int = player.count_item("wood")
    _check(after_wood == before_wood + 10, "Added 10 wood to inventory")
    var removed: int = player.remove_item("wood", 3)
    _check(removed == 0, "Removed 3 wood (no remaining)")
    _check(player.count_item("wood") == after_wood - 3, "Wood count is correct after removal")
    player._add_item("dirt", 99)
    _check(player.count_item("dirt") >= 99, "Can hold up to 99 dirt in one stack")
    _next_phase()


func _phase_4_test_crafting() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    player._add_item("wood", 30)
    var wood_before: int = player.count_item("wood")
    var pick_before: int = player.count_item("wood_pickaxe")
    var recipe: Dictionary = {}
    for r in RecipeDB.get_recipes():
        if r.get("result") == "wood_pickaxe":
            recipe = r
            break
    _check(not recipe.is_empty(), "Found wood_pickaxe recipe")
    if not recipe.is_empty():
        var stations: Array = world.get_nearby_stations(player.global_position)
        _log("Stations near player: " + str(stations))
        _check(RecipeDB.can_craft(recipe, player.inventory, stations), "Can craft wood_pickaxe")
        if RecipeDB.can_craft(recipe, player.inventory, stations):
            player.inventory = RecipeDB.consume_ingredients(player.inventory, recipe)
            player._add_item(recipe.result, recipe.count)
            var pick_after: int = player.count_item("wood_pickaxe")
            _check(pick_after == pick_before + 1, "Got a wood_pickaxe from crafting")
            var wood_after: int = player.count_item("wood")
            _check(wood_after == wood_before - 3, "Used 3 wood")
    # Place workbench near player
    var pt := WorldData.world_to_tile_pos(player.global_position)
    var wb_target := Vector2i(pt.x + 1, pt.y)
    if world.get_tile(wb_target.x, wb_target.y) != WorldData.Tile.AIR:
        wb_target = Vector2i(pt.x - 3, pt.y - 1)
    world.set_wall(wb_target.x, wb_target.y, WorldData.Tile.DIRT)
    world.set_tile(wb_target.x, wb_target.y, WorldData.Tile.WORKBENCH)
    await get_tree().process_frame
    var stations_after: Array = world.get_nearby_stations(player.global_position)
    _check(stations_after.has("workbench"), "Workbench is detected as nearby station")
    # Now test a workbench-required recipe
    player._add_item("copper_ore", 6)
    var bar_recipe: Dictionary = {}
    for r in RecipeDB.get_recipes():
        if r.get("result") == "copper_bar":
            bar_recipe = r
            break
    _check(not bar_recipe.is_empty(), "Found copper_bar recipe")
    if not bar_recipe.is_empty():
        _check(RecipeDB.can_craft(bar_recipe, player.inventory, stations_after), "Can craft copper_bar with workbench")
        if RecipeDB.can_craft(bar_recipe, player.inventory, stations_after):
            player.inventory = RecipeDB.consume_ingredients(player.inventory, bar_recipe)
            player._add_item(bar_recipe.result, bar_recipe.count)
            _check(player.count_item("copper_bar") >= 1, "Crafted copper_bar")
    _next_phase()


func _phase_5_test_combat() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    var enemy_scene := load("res://scenes/enemies/blue_slime.tscn")
    var enemy: Node = enemy_scene.instantiate()
    enemy.global_position = player.global_position + Vector2(40, -10)
    world.add_child(enemy)
    world.enemies.append(enemy)
    await get_tree().process_frame
    _check(is_instance_valid(enemy), "Enemy spawned")
    _check(enemy.health == 12, "Blue slime has 12 HP")
    var weapon: Dictionary = ItemDB.get_item("copper_sword")
    enemy.take_damage(weapon.damage, Vector2(100, 0))
    _check(enemy.health == 12 - weapon.damage, "Enemy took sword damage")
    # Wait for invuln to expire
    await get_tree().create_timer(0.3).timeout
    enemy.take_damage(100, Vector2(200, 0))
    await get_tree().create_timer(0.3).timeout
    _check(not is_instance_valid(enemy), "Enemy was killed and freed")
    _next_phase()


func _phase_6_test_boss_summon() -> void:
    if test_timer < 0.5:
        return
    phase_in_progress = true
    player._add_item("worm_food", 1)
    _check(player.count_item("worm_food") == 1, "Player has worm_food")
    world.summon_boss("eater_of_worlds", player.global_position + Vector2(100, -50))
    await get_tree().create_timer(0.5).timeout
    _check(world.boss_active, "Boss is active")
    _check(world.boss != null, "Boss reference is set")
    _check(world.boss.segments.size() == 15, "Boss has 15 segments")
    _next_phase()


func _phase_7_test_boss_combat() -> void:
    if test_timer < 1.0:
        return
    phase_in_progress = true
    if not world.boss or not is_instance_valid(world.boss):
        _check(false, "Boss still exists for combat test")
        _next_phase()
        return
    var head: Node = world.boss.segments[0]
    _check(head != null and is_instance_valid(head), "Head segment exists")
    var initial_hp: int = head.health
    head.take_damage(20, Vector2.ZERO)
    _check(head.health == initial_hp - 20, "Boss head took 20 damage")
    await get_tree().create_timer(0.3).timeout
    # Kill the head
    head.take_damage(100, Vector2.ZERO)
    await get_tree().create_timer(0.5).timeout
    _check(world.boss.segments.size() == 14, "Boss lost a segment (14 left)")
    if world.boss.segments.size() > 0:
        _check(world.boss.segments[0].is_head, "New head assigned after old head died")
    # Kill remaining segments one by one
    while world.boss and is_instance_valid(world.boss) and world.boss.segments.size() > 0:
        var seg: Node = world.boss.segments[0]
        if seg and is_instance_valid(seg):
            seg.take_damage(1000, Vector2.ZERO)
        await get_tree().create_timer(0.1).timeout
    await get_tree().create_timer(0.3).timeout
    _check(not world.boss_active or not is_instance_valid(world.boss), "Boss defeated (boss_active is false or boss freed)")
    _next_phase()


func _phase_finish() -> void:
    if test_timer < 1.0:
        return
    phase_in_progress = true
    print("\n=== Test Summary ===")
    print("Passes: ", passes)
    print("Failures: ", failures.size())
    for f in failures:
        print("  FAIL: ", f)
    print("=== TestGameplay DONE ===")
    get_tree().quit()
