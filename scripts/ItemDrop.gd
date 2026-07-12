class_name ItemDrop
extends Node2D
## A dropped item in the world. Has physics, attracts to player when close.

var item_id: String = ""
var count: int = 1
var velocity: Vector2 = Vector2.ZERO
var life_time: float = 0.0
const MAX_LIFE_TIME := 300.0  # 5 minutes

# Visual
var sprite: ColorRect = null
var label: Label = null

# Pickup settings
const PICKUP_RANGE := 50.0
const MAGNET_RANGE := 100.0
const PICKUP_DELAY := 0.5  # can't pick up for first 0.5s

signal picked_up


func _ready() -> void:
    # Create visual
    sprite = ColorRect.new()
    var item: Dictionary = ItemDB.get_item(item_id)
    sprite.color = item.get("icon_color", Color.MAGENTA)
    sprite.size = Vector2(10, 10)
    sprite.position = Vector2(-5, -5)
    add_child(sprite)

    # Count label (only if > 1)
    if count > 1:
        label = Label.new()
        label.text = str(count)
        label.position = Vector2(-8, -10)
        label.add_theme_font_size_override("font_size", 8)
        label.add_theme_color_override("font_color", Color.WHITE)
        label.add_theme_color_override("font_outline_color", Color.BLACK)
        label.add_theme_constant_override("outline_size", 2)
        add_child(label)

    set_process(true)


func set_initial_velocity(vel: Vector2) -> void:
    velocity = vel


func _process(delta: float) -> void:
    life_time += delta
    if life_time > MAX_LIFE_TIME:
        queue_free()
        return

    # Apply gravity
    velocity.y += 800 * delta
    velocity.y = min(velocity.y, 400)

    # Move with tile collision
    _move_and_collide(velocity * delta)

    # Friction
    velocity.x *= 0.95

    # Attract to player if close
    var player: Node = GameManager.player
    if player and life_time > PICKUP_DELAY:
        var to_player: Vector2 = (player.global_position - global_position)
        var dist: float = to_player.length()
        if dist < MAGNET_RANGE:
            var pull_strength := 1.0 - (dist / MAGNET_RANGE)
            velocity += to_player.normalized() * pull_strength * 600 * delta
        # Pickup
        if dist < PICKUP_RANGE:
            _try_pickup(player)


func _move_and_collide(movement: Vector2) -> void:
    # X axis
    global_position.x += movement.x
    if _check_collision():
        global_position.x -= movement.x
        velocity.x = 0
    # Y axis
    global_position.y += movement.y
    if _check_collision():
        global_position.y -= movement.y
        if movement.y > 0:
            velocity.y = 0
        else:
            velocity.y = 0


func _check_collision() -> bool:
    var world: Node = GameManager.world
    if not world:
        return false
    var aabb := Rect2(global_position.x - 5, global_position.y - 5, 10, 10)
    return world.check_aabb_collision(aabb, true)


func _try_pickup(player: Node) -> void:
    if not player or not player.has_method("_add_item"):
        return
    var remaining: int = player._add_item(item_id, count)
    if remaining < count:
        # Some picked up
        if remaining <= 0:
            picked_up.emit()
            queue_free()
        else:
            count = remaining
            if label:
                label.text = str(count)
