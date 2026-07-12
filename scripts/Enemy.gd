class_name Enemy
extends Node2D
## Base class for all enemies. Provides health, damage, knockback, tile physics.

# Health
var health: int = 10
var max_health: int = 10
var damage_flash: float = 0.0
var invuln_timer: float = 0.0
var dead: bool = false

# Physics
var velocity: Vector2 = Vector2.ZERO
const GRAVITY := 982.0
const MAX_FALL_SPEED := 500.0

# Combat
var contact_damage: int = 5
var contact_knockback: float = 100.0
var attack_cooldown: float = 0.0

# Dimensions (override in subclass)
var width: float = 14.0
var height: float = 14.0

# Sprite
var sprite: ColorRect = null

# Reference to world
var world: Node = null

# Lifetime (for despawning)
var lifetime: float = 0.0
const DESPAWN_DISTANCE := 1500.0  # despawn if too far from player

# Knockback resistance (0 = full knockback, 1 = immune)
var knockback_resistance: float = 0.0

# Damage drops (item_id -> chance)
var drops: Dictionary = {}

# Signals
signal died


func _ready() -> void:
    world = get_parent()
    while world and not world.has_method("get_tile"):
        world = world.get_parent()
    if world == null:
        push_error("Enemy: no world parent found!")
    set_process(true)


func setup_enemy(hp: int, dmg: int, w: float, h: float, color: Color) -> void:
    max_health = hp
    health = hp
    contact_damage = dmg
    width = w
    height = h
    if not sprite:
        sprite = ColorRect.new()
        add_child(sprite)
    sprite.color = color
    sprite.size = Vector2(width, height)
    sprite.position = Vector2(-width / 2, -height)


func _process(delta: float) -> void:
    if dead:
        return
    lifetime += delta

    # Update timers
    if damage_flash > 0:
        damage_flash -= delta
        if sprite:
            sprite.color = Color(1.0, 0.5, 0.5) if damage_flash > 0 else _get_normal_color()
    if invuln_timer > 0:
        invuln_timer -= delta
    if attack_cooldown > 0:
        attack_cooldown -= delta

    # AI behavior (override in subclass)
    _ai(delta)

    # Apply physics
    _apply_physics(delta)

    # Contact damage to player
    _check_player_contact()

    # Despawn if too far
    if GameManager.player:
        var dist: float = global_position.distance_to(GameManager.player.global_position)
        if dist > DESPAWN_DISTANCE:
            _despawn()


func _get_normal_color() -> Color:
    return Color.WHITE


func _ai(_delta: float) -> void:
    # Override in subclass
    pass


func _apply_physics(delta: float) -> void:
    # Apply gravity (unless flying enemy)
    if _uses_gravity():
        velocity.y += GRAVITY * delta
        velocity.y = min(velocity.y, MAX_FALL_SPEED)

    # Move X
    var move_x: float = velocity.x * delta
    _move_x(move_x)

    # Move Y
    var move_y: float = velocity.y * delta
    _move_y(move_y)

    # Friction
    if _is_on_ground():
        velocity.x *= 0.85


func _uses_gravity() -> bool:
    return true  # Override for flying enemies


func _move_x(dx: float) -> void:
    if dx == 0:
        return
    global_position.x += dx
    if _check_collision():
        global_position.x -= dx
        # Step to contact
        var step: float = dx
        for _i in range(6):
            step *= 0.5
            global_position.x += step
            if _check_collision():
                global_position.x -= step
        velocity.x = 0
        _on_hit_wall()


func _move_y(dy: float) -> void:
    if dy == 0:
        return
    global_position.y += dy
    if _check_collision():
        global_position.y -= dy
        var step: float = dy
        for _i in range(6):
            step *= 0.5
            global_position.y += step
            if _check_collision():
                global_position.y -= step
        if dy > 0:
            velocity.y = 0
        else:
            velocity.y = 0


func _check_collision() -> bool:
    var aabb := Rect2(global_position.x - width / 2, global_position.y - height, width, height)
    return world.check_aabb_collision(aabb, true)


func _is_on_ground() -> bool:
    var aabb := Rect2(global_position.x - width / 2, global_position.y, width, 2.0)
    return world.check_aabb_collision(aabb, true)


func _on_hit_wall() -> void:
    # Default: jump
    if _is_on_ground():
        velocity.y = -250


func _check_player_contact() -> void:
    if attack_cooldown > 0:
        return
    var player: Node = GameManager.player
    if not player or not is_instance_valid(player):
        return
    var player_aabb: Rect2 = player._get_aabb()
    var my_aabb := Rect2(global_position.x - width / 2, global_position.y - height, width, height)
    if my_aabb.intersects(player_aabb):
        var knockback_dir: Vector2 = (player.global_position - global_position).normalized()
        if knockback_dir == Vector2.ZERO:
            knockback_dir = Vector2.RIGHT
        player.take_damage(contact_damage, knockback_dir * contact_knockback)
        attack_cooldown = 1.0


func take_damage(amount: int, knockback: Vector2) -> void:
    if dead or invuln_timer > 0:
        return
    health -= amount
    damage_flash = 0.2
    invuln_timer = 0.15
    # Apply knockback (reduced by resistance)
    var kb_factor := 1.0 - knockback_resistance
    velocity += knockback * kb_factor
    if health <= 0:
        _die()


func _die() -> void:
    if dead:
        return
    dead = true
    died.emit()
    # Drop loot
    for item_id in drops:
        var chance: float = drops[item_id]
        if randf() < chance:
            var count := 1
            if item_id == "gel":
                count = randi_range(1, 3)
            elif item_id == "rotten_chunk":
                count = randi_range(1, 2)
            world.spawn_item_drop(item_id, count, global_position, Vector2(randf_range(-50, 50), -100))
    queue_free()


func _despawn() -> void:
    queue_free()


func _face_player() -> int:
    if not GameManager.player:
        return 1
    return 1 if GameManager.player.global_position.x > global_position.x else -1
