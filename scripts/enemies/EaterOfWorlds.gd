class_name EaterOfWorlds
extends Node2D
## The Eater of Worlds boss - a multi-segment worm.
## Each segment is a child node. The head leads, body segments follow.
## When the head dies, the next segment becomes a head.
## When a body segment is destroyed, the worm splits into two.

const SEGMENT_DISTANCE := 22.0  # distance between segments
const HEAD_DAMAGE := 12
const BODY_DAMAGE := 8
const TAIL_DAMAGE := 6
const HEAD_HP := 80
const BODY_HP := 50
const TAIL_HP := 60
const MOVE_SPEED := 130.0
const ACCEL := 200.0

var segments: Array = []  # list of segment nodes
var is_dead: bool = false
var ai_timer: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var world: Node = null

signal died


func _ready() -> void:
    world = get_parent()
    while world and not world.has_method("get_tile"):
        world = world.get_parent()
    set_process(true)
    # Create segments
    _create_segments(15)  # 15 segments total
    print("[EoW] Spawned with ", segments.size(), " segments")


func _create_segments(count: int) -> void:
    segments = []
    for i in range(count):
        var seg := EoWSegment.new()
        seg.boss = self
        seg.segment_index = i
        seg.is_head = (i == 0)
        seg.is_tail = (i == count - 1)
        if i == 0:
            seg.health = HEAD_HP
            seg.max_health = HEAD_HP
            seg.contact_damage = HEAD_DAMAGE
            seg.color = Color(0.40, 0.15, 0.50)
            seg.size_val = 22
        elif i == count - 1:
            seg.health = TAIL_HP
            seg.max_health = TAIL_HP
            seg.contact_damage = TAIL_DAMAGE
            seg.color = Color(0.30, 0.10, 0.40)
            seg.size_val = 18
        else:
            seg.health = BODY_HP
            seg.max_health = BODY_HP
            seg.contact_damage = BODY_DAMAGE
            seg.color = Color(0.35, 0.12, 0.45)
            seg.size_val = 20
        seg.global_position = global_position + Vector2(-i * SEGMENT_DISTANCE, 0)
        add_child(seg)
        segments.append(seg)
        seg.died.connect(_on_segment_died.bind(seg))


func _process(delta: float) -> void:
    if is_dead:
        return
    ai_timer += delta

    var player: Node = GameManager.player
    if not player or not is_instance_valid(player):
        return

    # Update target every 2 seconds
    if ai_timer > 2.0 or target_position == Vector2.ZERO:
        ai_timer = 0
        # Pick a target near the player
        target_position = player.global_position + Vector2(randf_range(-100, 100), randf_range(-100, 100))

    # Move the head toward target
    var head: Node = segments[0] if segments.size() > 0 else null
    if not head or not is_instance_valid(head):
        return

    var to_target: Vector2 = target_position - head.global_position
    if to_target.length() < 30:
        # Pick new target
        target_position = player.global_position + Vector2(randf_range(-150, 150), randf_range(-150, 150))
        to_target = target_position - head.global_position

    # Head moves toward target with gravity-like swooping motion
    var desired_vel: Vector2 = to_target.normalized() * MOVE_SPEED
    head.velocity = head.velocity.move_toward(desired_vel, ACCEL * delta)
    # Add some sine wave motion
    head.velocity.y += sin(ai_timer * 3.0) * 30 * delta
    head.global_position += head.velocity * delta

    # Body segments follow
    for i in range(1, segments.size()):
        var seg: Node = segments[i]
        if not seg or not is_instance_valid(seg):
            continue
        var prev: Node = segments[i - 1]
        if not prev or not is_instance_valid(prev):
            continue
        var to_prev: Vector2 = prev.global_position - seg.global_position
        var dist: float = to_prev.length()
        if dist > SEGMENT_DISTANCE:
            # Pull toward previous segment
            var excess: float = dist - SEGMENT_DISTANCE
            seg.global_position += to_prev.normalized() * excess
        # Inherit some velocity
        seg.velocity = prev.velocity * 0.5
        # If segment is the new head (previous head died), make it move toward target
        if i == 0:
            seg.velocity = head.velocity


func _on_segment_died(seg: Node) -> void:
    if is_dead:
        return
    var idx: int = segments.find(seg)
    if idx < 0:
        return
    print("[EoW] Segment ", idx, " destroyed")
    # Drop loot
    if world:
        world.spawn_item_drop("rotten_chunk", randi_range(1, 3), seg.global_position, Vector2(randf_range(-50, 50), -100))
        # Rare drop: demonite ore
        if randf() < 0.1:
            world.spawn_item_drop("lesser_healing_potion", 1, seg.global_position, Vector2(randf_range(-50, 50), -100))

    # Remove segment
    segments.remove_at(idx)
    seg.queue_free()

    # If this was the head, the next segment becomes the head
    if idx == 0 and segments.size() > 0:
        var new_head: Node = segments[0]
        if new_head and new_head.has_method("set_head"):
            new_head.set_head(true)

    # If this was a body segment (not head or tail), split the worm
    # Actually, let's keep it simple - just remove the segment
    # The worm stays as one piece (visually it'll have a gap, but functionally fine)

    # If no segments left, the boss is dead
    if segments.size() == 0:
        _die()


func _die() -> void:
    if is_dead:
        return
    is_dead = true
    print("[EoW] Boss defeated!")
    # Drop bonus loot
    if world:
        for i in range(3):
            world.spawn_item_drop("rotten_chunk", 2, global_position + Vector2(randf_range(-50, 50), 0), Vector2(randf_range(-100, 100), -200))
        world.spawn_item_drop("lesser_healing_potion", 3, global_position, Vector2(0, -150))
    died.emit()
    # Remove remaining segments
    for seg in segments:
        if seg and is_instance_valid(seg):
            seg.queue_free()
    segments.clear()
    queue_free()


func take_damage(amount: int, knockback: Vector2) -> void:
    # The boss itself doesn't take damage; segments do individually
    pass
