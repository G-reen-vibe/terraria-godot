extends Enemy
## Zombie - night surface enemy, walks toward player, can break doors (not implemented)

const ZOMBIE_COLOR := Color(0.40, 0.55, 0.35)
const MOVE_SPEED := 65.0
const JUMP_VELOCITY := 320.0
var jump_check_timer: float = 0.0


func _ready() -> void:
    super._ready()
    setup_enemy(20, 6, 14.0, 26.0, ZOMBIE_COLOR)
    contact_knockback = 150.0
    drops = {"gel": 0.3}
    # Add a "head" color rect
    var head := ColorRect.new()
    head.color = Color(0.50, 0.65, 0.40)
    head.size = Vector2(width, 8)
    head.position = Vector2(-width / 2, -height)
    head.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(head)


func _get_normal_color() -> Color:
    return ZOMBIE_COLOR


func _ai(delta: float) -> void:
    var player: Node = GameManager.player
    if not player:
        return
    var dir: int = _face_player()
    # Walk toward player
    velocity.x = move_toward(velocity.x, dir * MOVE_SPEED, 300 * delta)

    # Jump if there's a wall ahead
    jump_check_timer += delta
    if jump_check_timer > 0.3 and _is_on_ground():
        jump_check_timer = 0
        # Check if there's a solid tile in front (at body height)
        var check_x: float = global_position.x + dir * (width / 2 + 4)
        var check_y_top: float = global_position.y - height + 4
        var check_y_mid: float = global_position.y - height / 2
        var tile_front_top := WorldData.world_to_tile_pos(Vector2(check_x, check_y_top))
        var tile_front_mid := WorldData.world_to_tile_pos(Vector2(check_x, check_y_mid))
        if world.is_solid_at_tile(tile_front_top.x, tile_front_top.y) or world.is_solid_at_tile(tile_front_mid.x, tile_front_mid.y):
            velocity.y = -JUMP_VELOCITY
