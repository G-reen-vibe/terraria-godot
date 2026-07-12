class_name GuideNPC
extends Node2D
## The Guide NPC - provides tips to the player.

const NPC_COLOR := Color(0.55, 0.45, 0.35)
const MOVE_SPEED := 50.0
const JUMP_VELOCITY := 320.0

var velocity: Vector2 = Vector2.ZERO
var width: float = 12.0
var height: float = 28.0
var sprite: ColorRect = null
var world: Node = null
var home_pos: Vector2 = Vector2.ZERO
var talk_timer: float = 0.0
var message_label: Label = null
var current_message: String = ""


func _ready() -> void:
    world = get_parent()
    while world and not world.has_method("get_tile"):
        world = world.get_parent()
    sprite = ColorRect.new()
    sprite.color = NPC_COLOR
    sprite.size = Vector2(width, height)
    sprite.position = Vector2(-width / 2, -height)
    add_child(sprite)
    # Head
    var head := ColorRect.new()
    head.color = Color(0.85, 0.65, 0.55)
    head.size = Vector2(width, 8)
    head.position = Vector2(-width / 2, -height)
    head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(head)
    # Message label (above head)
    message_label = Label.new()
    message_label.text = ""
    message_label.position = Vector2(-50, -height - 20)
    message_label.size = Vector2(100, 16)
    message_label.add_theme_font_size_override("font_size", 9)
    message_label.add_theme_color_override("font_color", Color.WHITE)
    message_label.add_theme_color_override("font_outline_color", Color.BLACK)
    message_label.add_theme_constant_override("outline_size", 2)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(message_label)
    set_process(true)


func set_home(pos: Vector2) -> void:
    home_pos = pos
    global_position = pos


func _process(delta: float) -> void:
    # Simple AI: walk around home, jump if stuck
    # Apply gravity
    velocity.y += 982 * delta
    velocity.y = min(velocity.y, 500)

    # Walk back and forth near home
    var dist_from_home: float = abs(global_position.x - home_pos.x)
    if dist_from_home > 60:
        velocity.x = move_toward(velocity.x, sign(home_pos.x - global_position.x) * MOVE_SPEED, 200 * delta)
    else:
        # Random walk
        if randf() < 0.01:
            velocity.x = randf_range(-MOVE_SPEED, MOVE_SPEED)
        elif randf() < 0.02:
            velocity.x = 0

    # Jump if there's a wall ahead
    if abs(velocity.x) > 1 and _is_on_ground():
        var dir: int = 1 if velocity.x > 0 else -1
        var check_x: float = global_position.x + dir * (width / 2 + 4)
        var check_y: float = global_position.y - height / 2
        var tile := WorldData.world_to_tile_pos(Vector2(check_x, check_y))
        if world.is_solid_at_tile(tile.x, tile.y):
            velocity.y = -JUMP_VELOCITY

    # Move with collision
    _move_x(velocity.x * delta)
    _move_y(velocity.y * delta)
    if _is_on_ground() and velocity.y >= 0:
        velocity.y = 0
        velocity.x *= 0.85

    # Show message if player is close
    var player: Node = GameManager.player
    if player:
        var dist: float = global_position.distance_to(player.global_position)
        if dist < 80:
            if current_message == "":
                _show_random_tip()
        else:
            current_message = ""
            if message_label:
                message_label.text = ""

    talk_timer += delta
    if talk_timer > 5.0 and current_message != "":
        current_message = ""
        if message_label:
            message_label.text = ""
        talk_timer = 0


func _show_random_tip() -> void:
    var tips: Array = [
        "Press E for inventory!",
        "Press C for crafting!",
        "Mine wood with axe!",
        "Mine stone with pickaxe!",
        "Build a workbench!",
        "Get 5 rotten chunks + vile mushroom for Worm Food!",
        "Use Worm Food in corruption to summon Eater of Worlds!",
        "Press number keys to switch hotbar!",
        "Click to use selected item!",
        "Right click to place blocks!",
    ]
    current_message = tips[randi() % tips.size()]
    if message_label:
        message_label.text = current_message
    talk_timer = 0


func _move_x(dx: float) -> void:
    if dx == 0:
        return
    global_position.x += dx
    if _check_collision():
        global_position.x -= dx
        velocity.x = 0


func _move_y(dy: float) -> void:
    if dy == 0:
        return
    global_position.y += dy
    if _check_collision():
        global_position.y -= dy
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
