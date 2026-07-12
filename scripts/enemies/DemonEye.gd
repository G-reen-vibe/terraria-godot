extends Enemy
## Demon Eye - flying night enemy, swoops at player

const EYE_COLOR := Color(0.85, 0.30, 0.30)
const MOVE_SPEED := 90.0
const SWOOP_HEIGHT := 80.0
var ai_timer: float = 0.0
var target_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
    super._ready()
    setup_enemy(14, 5, 14.0, 14.0, EYE_COLOR)
    contact_knockback = 120.0
    drops = {"gel": 0.4}
    # Add a wing/iris detail
    var iris := ColorRect.new()
    iris.color = Color(0.95, 0.85, 0.20)
    iris.size = Vector2(6, 6)
    iris.position = Vector2(-3, -height + 4)
    iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(iris)


func _get_normal_color() -> Color:
    return EYE_COLOR


func _uses_gravity() -> bool:
    return false


func _ai(delta: float) -> void:
    var player: Node = GameManager.player
    if not player:
        return
    ai_timer += delta
    if ai_timer > 1.5:
        ai_timer = 0
        # Pick a new offset around the player
        target_offset = Vector2(randf_range(-100, 100), randf_range(-SWOOP_HEIGHT - 40, -SWOOP_HEIGHT + 20))

    var target_pos: Vector2 = player.global_position + target_offset
    var to_target: Vector2 = target_pos - global_position
    velocity = velocity.move_toward(to_target.normalized() * MOVE_SPEED, 200 * delta)
