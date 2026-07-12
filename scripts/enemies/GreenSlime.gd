extends Enemy
## Green Slime - weaker than blue, often drops less gel

const SLIME_COLOR := Color(0.40, 0.65, 0.30, 0.85)
const HOP_VELOCITY := 160.0
const MOVE_SPEED := 50.0
var hop_timer: float = 0.0
var hop_interval: float = 1.8


func _ready() -> void:
    super._ready()
    setup_enemy(8, 3, 14.0, 12.0, SLIME_COLOR)
    drops = {"gel": 0.7}
    hop_interval = randf_range(1.2, 2.2)


func _get_normal_color() -> Color:
    return SLIME_COLOR


func _ai(delta: float) -> void:
    hop_timer += delta
    var player: Node = GameManager.player
    if not player:
        return
    var dir: int = _face_player()
    if hop_timer >= hop_interval and _is_on_ground():
        hop_timer = 0
        hop_interval = randf_range(1.2, 2.2)
        velocity.y = -HOP_VELOCITY
        velocity.x = dir * MOVE_SPEED * 1.5
    elif _is_on_ground():
        velocity.x = move_toward(velocity.x, dir * MOVE_SPEED * 0.2, 80 * delta)
