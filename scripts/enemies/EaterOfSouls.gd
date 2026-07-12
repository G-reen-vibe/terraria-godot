extends Enemy
## Eater of Souls - flying corruption enemy, drops rotten chunks

const EYE_COLOR := Color(0.40, 0.20, 0.55)
const MOVE_SPEED := 75.0
var ai_timer: float = 0.0
var circle_angle: float = 0.0


func _ready() -> void:
    super._ready()
    setup_enemy(18, 7, 16.0, 16.0, EYE_COLOR)
    contact_knockback = 130.0
    drops = {"rotten_chunk": 0.5, "gel": 0.3}
    circle_angle = randf() * TAU


func _get_normal_color() -> Color:
    return EYE_COLOR


func _uses_gravity() -> bool:
    return false


func _ai(delta: float) -> void:
    var player: Node = GameManager.player
    if not player:
        return
    ai_timer += delta
    circle_angle += delta * 1.5
    # Circle the player, occasionally swooping
    var radius := 100.0
    if int(ai_timer) % 4 == 0:
        radius = 40.0  # Swoop closer
    var target_pos: Vector2 = player.global_position + Vector2(cos(circle_angle), sin(circle_angle) * 0.5) * radius
    var to_target: Vector2 = target_pos - global_position
    velocity = velocity.move_toward(to_target.normalized() * MOVE_SPEED, 150 * delta)
