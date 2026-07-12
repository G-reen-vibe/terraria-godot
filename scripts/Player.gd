class_name Player
extends Node2D
## The player character. Uses custom tile-based collision (not Godot physics).

# Physics
var velocity: Vector2 = Vector2.ZERO
const MOVE_SPEED := 180.0
const ACCEL := 1200.0
const AIR_ACCEL := 600.0
const JUMP_VELOCITY := 380.0
const GRAVITY := 982.0
const MAX_FALL_SPEED := 600.0
const TERMINAL_VELOCITY := 800.0

# Player dimensions (AABB)
const WIDTH := 12.0
const HEIGHT := 28.0

# State
var health: int = 100
var max_health: int = 100
var mana: int = 20
var max_mana: int = 20
var defense: int = 0

# Inventory
var inventory: Array = []  # 40 slots (10 hotbar + 30 main)
var hotbar_index: int = 0
var equipped_armor: Dictionary = {"head": null, "chest": null, "legs": null}
var equipped_accessories: Array = []  # up to 3

# Mining state
var mining_target: Vector2i = Vector2i(-1, -1)
var mining_progress: float = 0.0
var mining_time_total: float = 0.0

# Combat state
var attack_cooldown: float = 0.0
var attack_swing_time: float = 0.0
var attack_direction: Vector2 = Vector2.RIGHT

# Regeneration
var health_regen_timer: float = 0.0
var health_regen_rate: float = 0.5  # HP per second
var mana_regen_timer: float = 0.0
var mana_regen_rate: float = 2.0  # mana per second
var no_damage_timer: float = 0.0  # time since last damage taken

# Damage flash
var damage_flash: float = 0.0
var invuln_timer: float = 0.0  # i-frames after taking damage

# Visual
var facing: int = 1  # 1 = right, -1 = left
var sprite: ColorRect = null
var swing_arc: Node2D = null  # Visual for sword swing
var mining_arc: Node2D = null  # Visual for mining

# Camera
var camera: Camera2D = null

# Inventory UI
var inventory_ui: Node = null

# Reference to world
var world: Node = null

# Input state
var mouse_pos: Vector2 = Vector2.ZERO
var mouse_world_pos: Vector2 = Vector2.ZERO

# Cooldown for placing blocks (prevent spam)
var place_cooldown: float = 0.0

# Crafting UI open?
var crafting_ui_open: bool = false
var inventory_ui_open: bool = false

# Signals
signal health_changed(health: int, max_health: int)
signal mana_changed(mana: int, max_mana: int)
signal died
signal inventory_changed
signal hotbar_changed(index: int)


func _ready() -> void:
    # Find world
    world = get_parent()
    while world and not world.has_method("get_tile"):
        world = world.get_parent()
    if world == null:
        push_error("Player: no world parent found!")

    # Create sprite (simple colored rectangle for now)
    sprite = ColorRect.new()
    sprite.color = Color(0.85, 0.65, 0.55)  # skin tone
    sprite.size = Vector2(WIDTH, HEIGHT)
    sprite.position = Vector2(-WIDTH / 2, -HEIGHT)
    add_child(sprite)

    # Head (different color)
    var head := ColorRect.new()
    head.color = Color(0.40, 0.25, 0.15)  # hair
    head.size = Vector2(WIDTH, 8)
    head.position = Vector2(-WIDTH / 2, -HEIGHT)
    add_child(head)

    # Sword swing arc visual
    swing_arc = Node2D.new()
    swing_arc.visible = false
    add_child(swing_arc)
    # Draw arc using _draw
    var arc_draw := _ArcDraw.new()
    arc_draw.color = Color(1.0, 1.0, 1.0, 0.5)
    swing_arc.add_child(arc_draw)

    # Mining arc visual
    mining_arc = Node2D.new()
    mining_arc.visible = false
    add_child(mining_arc)

    # Camera
    camera = Camera2D.new()
    camera.enabled = true
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 8.0
    camera.zoom = Vector2(1.5, 1.5)  # Slight zoom in for visibility
    add_child(camera)

    # Initialize inventory (40 slots)
    inventory.resize(40)
    for i in range(40):
        inventory[i] = null

    # Give starting items
    _give_starting_items()

    # Set GameManager reference
    GameManager.player = self

    # Connect input handlers
    set_process(true)
    set_process_input(true)

    print("[Player] Ready at position ", global_position)


func _give_starting_items() -> void:
    # Starting items: copper pickaxe, copper axe, copper sword
    _add_item("copper_pickaxe", 1)
    _add_item("copper_axe", 1)
    _add_item("copper_sword", 1)
    _add_item("torch", 10)
    _add_item("wood_arrow", 50)
    _add_item("wood_bow", 1)


func _add_item(item_id: String, count: int) -> int:
    var item: Dictionary = ItemDB.get_item(item_id)
    if item.is_empty():
        return count
    var max_stack: int = item.get("max_stack", 99)
    # Try to stack with existing
    if max_stack > 1:
        for i in range(inventory.size()):
            if inventory[i] == null:
                continue
            if typeof(inventory[i]) != TYPE_DICTIONARY:
                continue
            if inventory[i].get("id", "") == item_id:
                var cur: int = inventory[i].get("count", 0)
                if cur < max_stack:
                    var can_add: int = min(max_stack - cur, count)
                    inventory[i]["count"] = cur + can_add
                    count -= can_add
                    if count <= 0:
                        return 0
    # Add to empty slots
    while count > 0:
        var slot := _find_empty_slot()
        if slot < 0:
            return count  # Inventory full
        var add: int = min(max_stack, count)
        inventory[slot] = {"id": item_id, "count": add}
        count -= add
    inventory_changed.emit()
    return 0


func _find_empty_slot() -> int:
    for i in range(inventory.size()):
        if inventory[i] == null:
            return i
    return -1


func remove_item(item_id: String, count: int) -> int:
    var remaining := count
    for i in range(inventory.size()):
        if remaining <= 0:
            break
        if inventory[i] == null or typeof(inventory[i]) != TYPE_DICTIONARY:
            continue
        if inventory[i].get("id", "") == item_id:
            var cur: int = inventory[i].get("count", 0)
            var take: int = min(cur, remaining)
            inventory[i]["count"] = cur - take
            remaining -= take
            if inventory[i]["count"] <= 0:
                inventory[i] = null
    if remaining < count:
        inventory_changed.emit()
    return remaining


func count_item(item_id: String) -> int:
    var total := 0
    for slot in inventory:
        if slot == null or typeof(slot) != TYPE_DICTIONARY:
            continue
        if slot.get("id", "") == item_id:
            total += slot.get("count", 0)
    return total


func get_selected_item() -> Variant:
    if hotbar_index < 0 or hotbar_index >= 10:
        return null
    return inventory[hotbar_index]


func _process(delta: float) -> void:
    if GameManager.paused or GameManager.game_over:
        return
    # Update mouse position
    mouse_pos = get_viewport().get_mouse_position()
    var canvas_transform := get_canvas_transform()
    mouse_world_pos = (mouse_pos - canvas_transform.get_origin()) / canvas_transform.get_scale()

    # Update timers
    if attack_cooldown > 0:
        attack_cooldown -= delta
    if attack_swing_time > 0:
        attack_swing_time -= delta
        if attack_swing_time <= 0:
            swing_arc.visible = false
    if place_cooldown > 0:
        place_cooldown -= delta
    if damage_flash > 0:
        damage_flash -= delta
        sprite.color = Color(1.0, 0.5, 0.5) if damage_flash > 0 else Color(0.85, 0.65, 0.55)
    if invuln_timer > 0:
        invuln_timer -= delta

    # Regen
    no_damage_timer += delta
    if no_damage_timer > 5.0 and health < max_health:
        health_regen_timer += delta
        if health_regen_timer > 1.0 / health_regen_rate:
            health = min(max_health, health + 1)
            health_regen_timer = 0.0
            health_changed.emit(health, max_health)
    if mana < max_mana:
        mana_regen_timer += delta
        if mana_regen_timer > 1.0 / mana_regen_rate:
            mana = min(max_mana, mana + 1)
            mana_regen_timer = 0.0
            mana_changed.emit(mana, max_mana)

    # Update defense from equipment
    _update_defense()

    # Handle input
    _handle_input(delta)

    # Apply physics
    _apply_physics(delta)

    # Handle mining/placing
    _handle_world_interaction(delta)

    # Redraw for swing/mining visuals
    queue_redraw()

    # Clamp to world bounds
    var world_w: float = WorldData.WORLD_WIDTH * WorldData.TILE_SIZE
    var world_h: float = WorldData.WORLD_HEIGHT * WorldData.TILE_SIZE
    global_position.x = clamp(global_position.x, 0, world_w)
    if global_position.y > world_h + 100:
        # Fell out of world
        take_damage(999, Vector2.ZERO)


func _update_defense() -> void:
    var def := 0
    for slot_name in equipped_armor:
        var item_id: Variant = equipped_armor[slot_name]
        if item_id:
            var item: Dictionary = ItemDB.get_item(item_id)
            def += item.get("defense", 0)
    for acc_id in equipped_accessories:
        if acc_id:
            pass  # accessories handled separately
    defense = def


func _handle_input(delta: float) -> void:
    var input_vec := Vector2.ZERO
    if Input.is_action_pressed("move_left"):
        input_vec.x -= 1
        facing = -1
    if Input.is_action_pressed("move_right"):
        input_vec.x += 1
        facing = 1

    # Acceleration
    var accel := ACCEL if _is_on_ground() else AIR_ACCEL
    if input_vec.x != 0:
        velocity.x = move_toward(velocity.x, input_vec.x * MOVE_SPEED, accel * delta)
    else:
        # Friction
        var friction := ACCEL if _is_on_ground() else AIR_ACCEL * 0.3
        velocity.x = move_toward(velocity.x, 0, friction * delta)

    # Jump
    if Input.is_action_just_pressed("jump") and _is_on_ground():
        velocity.y = -JUMP_VELOCITY

    # Hotbar selection
    for i in range(10):
        if Input.is_action_just_pressed("hotbar_" + str(i + 1)):
            hotbar_index = i
            hotbar_changed.emit(i)
            print("[Player] Hotbar: ", i)


func _apply_physics(delta: float) -> void:
    # Apply gravity
    velocity.y += GRAVITY * delta
    velocity.y = min(velocity.y, MAX_FALL_SPEED)

    # Move X first, resolve collisions
    var move_x: float = velocity.x * delta
    _move_axis(move_x, 0.0)

    # Move Y, resolve collisions
    var move_y: float = velocity.y * delta
    _move_axis(0.0, move_y)


func _move_axis(dx: float, dy: float) -> void:
    # Move and resolve tile collisions
    # X axis: only check solid tiles (player passes through platforms horizontally)
    if dx != 0:
        global_position.x += dx
        if _check_solid_collision():
            global_position.x -= dx
            # Binary search to find contact point
            var step: float = dx
            for _i in range(8):
                step *= 0.5
                global_position.x += step
                if _check_solid_collision():
                    global_position.x -= step
            velocity.x = 0
    # Y axis
    if dy != 0:
        if dy > 0:
            # Moving down - check solid first, then platforms
            global_position.y += dy
            if _check_solid_collision():
                # Hit solid ground - binary search
                global_position.y -= dy
                var step: float = dy
                for _i in range(8):
                    step *= 0.5
                    global_position.y += step
                    if _check_solid_collision():
                        global_position.y -= step
                velocity.y = 0
            else:
                # Check platform collision - snap to platform top if crossed
                var snap_y: float = _check_platform_landing(dy)
                if snap_y < 1e9:
                    global_position.y = snap_y
                    velocity.y = 0
        else:
            # Moving up - only check solid
            global_position.y += dy
            if _check_solid_collision():
                global_position.y -= dy
                var step: float = dy
                for _i in range(8):
                    step *= 0.5
                    global_position.y += step
                    if _check_solid_collision():
                        global_position.y -= step
                velocity.y = 0


func _get_aabb() -> Rect2:
    # Player AABB in world coords. global_position.y is at the player's FEET.
    return Rect2(
        global_position.x - WIDTH / 2,
        global_position.y - HEIGHT,
        WIDTH,
        HEIGHT
    )


func _check_solid_collision() -> bool:
    # Check if player's AABB overlaps any SOLID tile (not platforms)
    var aabb := _get_aabb()
    return world.check_aabb_collision(aabb, true)  # ignore_platforms=true


## Check if player landed on a platform while falling.
## Returns the y position to snap to, or 1e9 if no landing.
func _check_platform_landing(dy: float) -> float:
    var aabb := _get_aabb()
    var feet_y: float = aabb.position.y + aabb.size.y  # = global_position.y
    var prev_feet_y: float = feet_y - dy  # position before the move
    var tx0: int = int(aabb.position.x / WorldData.TILE_SIZE)
    var tx1: int = int((aabb.position.x + aabb.size.x - 0.01) / WorldData.TILE_SIZE)
    # Check the tile row at the player's feet
    var ty: int = int(feet_y / WorldData.TILE_SIZE)
    for tx in range(tx0, tx1 + 1):
        if world.is_platform_at_tile(tx, ty):
            var platform_top: float = ty * WorldData.TILE_SIZE
            # Player was above the platform before the move, and is now at or below it
            if prev_feet_y - 0.5 <= platform_top and feet_y >= platform_top:
                return platform_top - 0.01  # snap feet to platform top
    return 1e9  # no landing


func _check_collision() -> bool:
    # Legacy: check solid tiles only (for X axis)
    return _check_solid_collision()


func _check_collision_y(dy: float) -> bool:
    # Legacy: kept for compatibility
    if dy > 0:
        if _check_solid_collision():
            return true
        return _check_platform_landing(dy) < 1e9
    else:
        return _check_solid_collision()


func _is_on_ground() -> bool:
    # Check if player is standing on something (within 1 pixel)
    var aabb := _get_aabb()
    var test_rect := Rect2(aabb.position.x, aabb.position.y + aabb.size.y, aabb.size.x, 1.0)
    # Solid ground
    if world.check_aabb_collision(test_rect, true):
        return true
    # Platform ground
    var feet_y: float = aabb.position.y + aabb.size.y
    var tx0: int = int(aabb.position.x / WorldData.TILE_SIZE)
    var tx1: int = int((aabb.position.x + aabb.size.x - 0.01) / WorldData.TILE_SIZE)
    var ty: int = int(feet_y / WorldData.TILE_SIZE)
    for tx in range(tx0, tx1 + 1):
        if world.is_platform_at_tile(tx, ty):
            var platform_top: float = ty * WorldData.TILE_SIZE
            if abs(feet_y - platform_top) < 2.0:
                return true
    return false


# === World interaction (mining/placing/attacking) ===
func _handle_world_interaction(delta: float) -> void:
    # Don't interact with world when UI is open
    if inventory_ui_open or crafting_ui_open:
        mining_target = Vector2i(-1, -1)
        mining_progress = 0.0
        return
    var selected = get_selected_item()
    var use_pressed := Input.is_action_pressed("use")
    var alt_pressed := Input.is_action_pressed("alt_use")

    # Calculate target tile (where mouse is pointing)
    var target_tile := WorldData.world_to_tile_pos(mouse_world_pos)
    var reach: float = 80.0  # Default reach distance
    var is_consumable := false
    if selected and typeof(selected) == TYPE_DICTIONARY:
        var item_cat: int = selected.get("category", -1)
        if item_cat == ItemDB.ItemCategory.SWORD:
            reach = selected.get("range", 32)
        elif item_cat == ItemDB.ItemCategory.PICKAXE or item_cat == ItemDB.ItemCategory.AXE:
            reach = 80.0
        elif item_cat == ItemDB.ItemCategory.CONSUMABLE:
            is_consumable = true

    # Consumables don't need a target - use immediately
    if is_consumable and use_pressed:
        _do_consume(selected)
        return

    # Distance from player to target tile (use player center)
    var player_center := global_position - Vector2(0, HEIGHT / 2)
    var target_world := WorldData.tile_to_world_pos(target_tile.x, target_tile.y) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2)
    var dist := player_center.distance_to(target_world)

    if dist > reach:
        # Out of reach - reset mining
        mining_target = Vector2i(-1, -1)
        mining_progress = 0.0
        return

    if use_pressed:
        # Determine action based on selected item
        if selected and typeof(selected) == TYPE_DICTIONARY:
            var item_cat: int = selected.get("category", -1)
            match item_cat:
                ItemDB.ItemCategory.PICKAXE, ItemDB.ItemCategory.AXE:
                    _do_mining(delta, target_tile, selected)
                ItemDB.ItemCategory.SWORD:
                    _do_attack(delta, selected)
                ItemDB.ItemCategory.BOW:
                    _do_bow_attack(delta, selected)
                ItemDB.ItemCategory.PLACEABLE, ItemDB.ItemCategory.BLOCK:
                    _do_placing(target_tile, selected)
                ItemDB.ItemCategory.CONSUMABLE:
                    _do_consume(selected)
                _:
                    # Bare hands - mine weakly
                    _do_mining(delta, target_tile, {"id": "hand", "category": ItemDB.ItemCategory.TOOL, "tier": 0, "power": 10, "speed": 0.5})
        else:
            # Bare hands
            _do_mining(delta, target_tile, {"id": "hand", "category": ItemDB.ItemCategory.TOOL, "tier": 0, "power": 10, "speed": 0.5})
    else:
        # Not mining
        mining_target = Vector2i(-1, -1)
        mining_progress = 0.0

    if alt_pressed:
        # Alt use - place block (if not a tool/weapon)
        if selected and typeof(selected) == TYPE_DICTIONARY:
            var item_cat: int = selected.get("category", -1)
            if item_cat == ItemDB.ItemCategory.PLACEABLE or item_cat == ItemDB.ItemCategory.BLOCK:
                _do_placing(target_tile, selected)


func _do_mining(delta: float, target_tile: Vector2i, tool: Dictionary) -> void:
    var tile_id: int = world.get_tile(target_tile.x, target_tile.y)
    if tile_id == WorldData.Tile.AIR:
        mining_target = Vector2i(-1, -1)
        mining_progress = 0.0
        return
    if not WorldData.is_mineable(tile_id):
        return

    # Check tool type
    var tool_type := "any"
    var tool_tier: int = 0
    var tool_cat: int = tool.get("category", -1)
    match tool_cat:
        ItemDB.ItemCategory.PICKAXE:
            tool_type = "pickaxe"
            tool_tier = tool.get("tier", 0)
        ItemDB.ItemCategory.AXE:
            tool_type = "axe"
            tool_tier = tool.get("tier", 0)
        ItemDB.ItemCategory.TOOL:
            tool_type = "any"
            tool_tier = 0
        _:
            tool_type = "any"
            tool_tier = 0

    if not world.can_mine_tile(tile_id, tool_type, tool_tier):
        # Wrong tool - very slow
        mining_progress += delta * 0.1
    else:
        # Correct tool - mine at speed
        var hardness: float = WorldData.tile_hardness(tile_id)
        var speed: float = tool.get("speed", 1.0)
        var power: float = tool.get("power", 10)
        # Time to mine = hardness * 1.5 / (power / 30) / speed
        mining_time_total = hardness * 1.5 / (power / 30.0) / speed
        if mining_target != target_tile:
            mining_target = target_tile
            mining_progress = 0.0
        mining_progress += delta

    # Show mining visual
    mining_arc.visible = true
    mining_arc.global_position = WorldData.tile_to_world_pos(target_tile.x, target_tile.y) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2)
    mining_arc.queue_redraw()

    # Mining complete?
    if mining_progress >= mining_time_total:
        # Break the tile
        _break_tile(target_tile.x, target_tile.y, tile_id)
        mining_progress = 0.0
        mining_target = Vector2i(-1, -1)


func _break_tile(tx: int, ty: int, tile_id: int) -> void:
    world.set_tile(tx, ty, WorldData.Tile.AIR)
    # Drop item
    var drop_id := _tile_to_item_id(tile_id)
    if drop_id != "":
        world.spawn_item_drop(drop_id, 1, WorldData.tile_to_world_pos(tx, ty) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2))
    # Special drops from grass
    if tile_id == WorldData.Tile.GRASS:
        if randf() < 0.1:
            world.spawn_item_drop("mushroom", 1, WorldData.tile_to_world_pos(tx, ty) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2))
    elif tile_id == WorldData.Tile.CORRUPT_GRASS:
        if randf() < 0.15:
            world.spawn_item_drop("vile_mushroom", 1, WorldData.tile_to_world_pos(tx, ty) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2))
    # Special: if it was a tree trunk, also break leaves above
    if tile_id == WorldData.Tile.WOOD:
        # Check if it's a tree trunk (no solid block below)
        var below: int = world.get_tile(tx, ty + 1)
        if below == WorldData.Tile.AIR or below == WorldData.Tile.GRASS or below == WorldData.Tile.CORRUPT_GRASS:
            # It's the bottom of a tree - break everything above
            for dy in range(1, 15):
                var ny: int = ty - dy
                if ny < 0:
                    break
                var t: int = world.get_tile(tx, ny)
                if t == WorldData.Tile.WOOD:
                    world.set_tile(tx, ny, WorldData.Tile.AIR)
                    world.spawn_item_drop("wood", 1, WorldData.tile_to_world_pos(tx, ny) + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2))
                elif t == WorldData.Tile.LEAVES:
                    world.set_tile(tx, ny, WorldData.Tile.AIR)
                    # Maybe drop nothing or sapling
                else:
                    break
            # Also break adjacent leaves (canopy)
            for dy in range(0, 15):
                for dx in range(-3, 4):
                    if dx == 0:
                        continue
                    var nx: int = tx + dx
                    var ny: int = ty - dy
                    if nx < 0 or nx >= WorldData.WORLD_WIDTH or ny < 0:
                        continue
                    if world.get_tile(nx, ny) == WorldData.Tile.LEAVES:
                        # Only break if connected to the trunk (BFS would be better, but simplify)
                        if abs(dx) <= 2:
                            world.set_tile(nx, ny, WorldData.Tile.AIR)


func _tile_to_item_id(tile_id: int) -> String:
    match tile_id:
        WorldData.Tile.DIRT: return "dirt"
        WorldData.Tile.GRASS: return "dirt"  # Grass drops dirt
        WorldData.Tile.STONE: return "stone"
        WorldData.Tile.WOOD: return "wood"
        WorldData.Tile.LEAVES: return ""  # No drop
        WorldData.Tile.COPPER_ORE: return "copper_ore"
        WorldData.Tile.IRON_ORE: return "iron_ore"
        WorldData.Tile.SILVER_ORE: return "silver_ore"
        WorldData.Tile.GOLD_ORE: return "gold_ore"
        WorldData.Tile.CORRUPT_GRASS: return "corrupt_dirt"
        WorldData.Tile.CORRUPT_STONE: return "ebonstone"
        WorldData.Tile.CORRUPT_DIRT: return "corrupt_dirt"
        WorldData.Tile.EBONSTONE_BRICK: return "ebonstone_brick"
        WorldData.Tile.WOOD_PLATFORM: return "wood_platform"
        WorldData.Tile.WORKBENCH: return "workbench"
        WorldData.Tile.TORCH: return "torch"
        WorldData.Tile.CHEST: return "chest"
        WorldData.Tile.SAND: return "sand"
        WorldData.Tile.ASH: return "ash"
        _: return ""


func _do_attack(delta: float, weapon: Dictionary) -> void:
    if attack_cooldown > 0:
        return
    attack_cooldown = weapon.get("speed", 0.4)
    attack_swing_time = attack_cooldown * 0.6
    attack_direction = (mouse_world_pos - (global_position - Vector2(0, HEIGHT / 2))).normalized()
    if attack_direction.x > 0:
        facing = 1
    else:
        facing = -1

    # Show swing arc
    swing_arc.visible = true
    swing_arc.global_position = global_position - Vector2(0, HEIGHT / 2)
    swing_arc.queue_redraw()

    # Damage enemies in range
    var damage: int = weapon.get("damage", 5)
    var range_val: float = weapon.get("range", 32)
    var knockback: float = weapon.get("knockback", 4.0)

    # Find enemies within range and arc
    var hit_something := false
    for enemy in world.enemies.duplicate():
        if not is_instance_valid(enemy):
            continue
        var to_enemy: Vector2 = enemy.global_position - (global_position - Vector2(0, HEIGHT / 2))
        if to_enemy.length() > range_val + 16:
            continue
        # Check angle - within ~70 degrees of attack direction
        var angle_diff := rad_to_deg(abs(attack_direction.angle_to(to_enemy)))
        if angle_diff > 70:
            continue
        # Hit!
        if enemy.has_method("take_damage"):
            enemy.take_damage(damage, to_enemy.normalized() * knockback * 50)
            hit_something = true
    # Hit boss segments (each segment is a separate target)
    if world.boss and is_instance_valid(world.boss):
        var boss_segments: Variant = world.boss.get("segments")
        if boss_segments is Array:
            for seg in (boss_segments as Array).duplicate():
                if not is_instance_valid(seg):
                    continue
                var to_seg: Vector2 = seg.global_position - (global_position - Vector2(0, HEIGHT / 2))
                if to_seg.length() > range_val + 16:
                    continue
                var angle_diff := rad_to_deg(abs(attack_direction.angle_to(to_seg)))
                if angle_diff > 70:
                    continue
                if seg.has_method("take_damage"):
                    seg.take_damage(damage, to_seg.normalized() * knockback * 50)
                    hit_something = true


func _do_bow_attack(delta: float, weapon: Dictionary) -> void:
    if attack_cooldown > 0:
        return
    # Need arrows
    if count_item("wood_arrow") <= 0:
        return
    remove_item("wood_arrow", 1)
    attack_cooldown = weapon.get("speed", 0.6)
    attack_direction = (mouse_world_pos - (global_position - Vector2(0, HEIGHT / 2))).normalized()
    if attack_direction.x > 0:
        facing = 1
    else:
        facing = -1
    # Spawn arrow projectile
    var arrow_scene: Resource = load("res://scenes/world/Arrow.tscn")
    var arrow: Node = arrow_scene.instantiate()
    arrow.global_position = global_position - Vector2(0, HEIGHT / 2) + attack_direction * 12
    arrow.set_direction(attack_direction, 600)
    arrow.damage = weapon.get("damage", 6) + 4  # arrow adds damage
    world.add_child(arrow)
    world.projectiles.append(arrow)


func _do_placing(target_tile: Vector2i, item: Dictionary) -> void:
    if place_cooldown > 0:
        return
    var tile_id: int = item.get("tile", -1)
    if tile_id < 0:
        return
    # Check if target is empty (or platform being placed on solid)
    var current: int = world.get_tile(target_tile.x, target_tile.y)
    if current != WorldData.Tile.AIR:
        # Allow placing on platforms? For now, no
        return
    # Check if there's a neighbor (so blocks don't float)
    var has_neighbor := false
    for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
        var nt: int = world.get_tile(target_tile.x + dir.x, target_tile.y + dir.y)
        if nt != WorldData.Tile.AIR:
            has_neighbor = true
            break
    # Or wall behind
    if not has_neighbor:
        var wall: int = world.get_wall(target_tile.x, target_tile.y)
        if wall != WorldData.Tile.AIR:
            has_neighbor = true
    if not has_neighbor:
        return
    # Don't place inside player
    var tile_world_pos := WorldData.tile_to_world_pos(target_tile.x, target_tile.y)
    var player_aabb := _get_aabb()
    var tile_rect := Rect2(tile_world_pos, Vector2(WorldData.TILE_SIZE, WorldData.TILE_SIZE))
    if WorldData.is_solid(tile_id) and player_aabb.intersects(tile_rect):
        return
    # Place it
    world.set_tile(target_tile.x, target_tile.y, tile_id)
    remove_item(item.get("id", ""), 1)
    place_cooldown = 0.15


func _do_consume(item: Dictionary) -> void:
    if attack_cooldown > 0:
        return
    attack_cooldown = 1.0
    var heal: int = item.get("heal", 0)
    var mana_restore: int = item.get("mana", 0)
    var use: String = item.get("use", "")
    if heal > 0:
        health = min(max_health, health + heal)
        health_changed.emit(health, max_health)
    if mana_restore > 0:
        mana = min(max_mana, mana + mana_restore)
        mana_changed.emit(mana, max_mana)
    if use == "summon_eow":
        # Summon Eater of Worlds
        var spawn_pos := global_position + Vector2(0, -100)
        world.summon_boss("eater_of_worlds", spawn_pos)
    remove_item(item.get("id", ""), 1)


func take_damage(amount: int, knockback: Vector2) -> void:
    if invuln_timer > 0:
        return
    var actual: int = max(1, amount - defense)
    health -= actual
    damage_flash = 0.3
    invuln_timer = 0.5
    no_damage_timer = 0
    health_regen_timer = 0
    # Apply knockback
    velocity += knockback
    health_changed.emit(health, max_health)
    if health <= 0:
        _die()


func _die() -> void:
    print("[Player] Died!")
    GameManager.game_over = true
    died.emit()


func heal(amount: int) -> void:
    health = min(max_health, health + amount)
    health_changed.emit(health, max_health)


func _draw() -> void:
    # Draw swing arc if active (at player center)
    if attack_swing_time > 0:
        var progress: float = 1.0 - (attack_swing_time / max(attack_cooldown * 0.6, 0.01))
        var arc_span := deg_to_rad(100.0)  # 100 degree arc
        var base_angle := attack_direction.angle()
        var current_angle := base_angle - arc_span / 2 + arc_span * progress
        var radius := 32.0
        var steps := 10
        var points: PackedVector2Array = []
        points.append(Vector2.ZERO)
        for i in range(steps + 1):
            var t: float = float(i) / steps
            var a: float = current_angle - 0.4 + t * 0.8  # small arc around current angle
            points.append(Vector2(cos(a), sin(a)) * radius)
        # Draw at player center (which is global_position - Vector2(0, HEIGHT/2) in world space,
        # but _draw is in local space so we use Vector2(0, -HEIGHT/2))
        var draw_pos := Vector2(0, -HEIGHT / 2)
        # Transform points to local
        var local_points: PackedVector2Array = []
        for p in points:
            local_points.append(p + draw_pos)
        draw_colored_polygon(local_points, Color(1.0, 1.0, 0.9, 0.4))
    
    # Draw mining crack on target tile
    if mining_target.x >= 0 and mining_progress > 0 and mining_time_total > 0:
        var progress: float = mining_progress / mining_time_total
        var crack_pos := WorldData.tile_to_world_pos(mining_target.x, mining_target.y) - global_position + Vector2(WorldData.TILE_SIZE / 2, WorldData.TILE_SIZE / 2)
        # Draw crack lines
        var crack_color := Color(0, 0, 0, progress * 0.6)
        draw_rect(Rect2(crack_pos - Vector2(6, 6), Vector2(12, 12)), crack_color, false, 2)
        if progress > 0.3:
            draw_line(crack_pos - Vector2(5, 0), crack_pos + Vector2(5, 0), crack_color, 1)
        if progress > 0.6:
            draw_line(crack_pos - Vector2(0, 5), crack_pos + Vector2(0, 5), crack_color, 1)


# Inner class for drawing arc (kept for compatibility, unused)
class _ArcDraw:
    extends Node2D
    var color: Color = Color(1, 1, 1, 0.5)
    var radius: float = 30.0
    var angle_deg: float = 80.0
    var current_angle: float = 0.0

    func _draw() -> void:
        var start_angle: float = deg_to_rad(current_angle - angle_deg / 2)
        var end_angle: float = deg_to_rad(current_angle + angle_deg / 2)
        var points: PackedVector2Array = []
        points.append(Vector2.ZERO)
        var steps := 12
        for i in range(steps + 1):
            var t: float = float(i) / steps
            var a: float = lerp(start_angle, end_angle, t)
            points.append(Vector2(cos(a), sin(a)) * radius)
        draw_colored_polygon(points, color)
