extends Enemy
## Blue Slime - basic surface enemy, hops toward player

const SLIME_COLOR := Color(0.30, 0.50, 0.85, 0.85)
const HOP_VELOCITY := 180.0
const MOVE_SPEED := 60.0
var hop_timer: float = 0.0
var hop_interval: float = 1.5


func _ready() -> void:
    super._ready()
    setup_enemy(12, 4, 14.0, 12.0, SLIME_COLOR)
    drops = {"gel": 1.0}
    hop_interval = randf_range(1.0, 2.0)


func _get_normal_color() -> Color:
    return SLIME_COLOR


func _ai(delta: float) -> void:
    hop_timer += delta
    var player: Node = GameManager.player
    if not player:
        return
    var dir: int = _face_player()
    var dist: float = global_position.distance_to(player.global_position)

    if hop_timer >= hop_interval and _is_on_ground():
        hop_timer = 0
        hop_interval = randf_range(1.0, 2.0)
        velocity.y = -HOP_VELOCITY
        velocity.x = dir * MOVE_SPEED * 1.5
    elif not _is_on_ground():
        # Maintain horizontal velocity in air
        pass
    else:
        # Slow down on ground
        velocity.x = move_toward(velocity.x, dir * MOVE_SPEED * 0.3, 100 * delta)
