class_name EoWSegment
extends Node2D
## A single segment of the Eater of Worlds boss.

var boss: Node = null  # Reference to parent boss
var segment_index: int = 0
var is_head: bool = false
var is_tail: bool = false

var health: int = 50
var max_health: int = 50
var contact_damage: int = 8
var velocity: Vector2 = Vector2.ZERO
var damage_flash: float = 0.0
var invuln_timer: float = 0.0
var attack_cooldown: float = 0.0

var color: Color = Color(0.35, 0.12, 0.45)
var size_val: float = 20.0

var sprite: ColorRect = null
var eye_sprite: ColorRect = null  # Only on head

signal died


func _ready() -> void:
    set_process(true)
    sprite = ColorRect.new()
    sprite.color = color
    sprite.size = Vector2(size_val, size_val)
    sprite.position = Vector2(-size_val / 2, -size_val / 2)
    sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(sprite)

    if is_head:
        # Add eyes
        eye_sprite = ColorRect.new()
        eye_sprite.color = Color(1.0, 0.85, 0.20)
        eye_sprite.size = Vector2(4, 4)
        eye_sprite.position = Vector2(0, -3)
        eye_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(eye_sprite)


func _process(delta: float) -> void:
    if damage_flash > 0:
        damage_flash -= delta
        if sprite:
            sprite.color = Color(1.0, 0.5, 0.5) if damage_flash > 0 else color
    if invuln_timer > 0:
        invuln_timer -= delta
    if attack_cooldown > 0:
        attack_cooldown -= delta

    # Contact damage to player
    if attack_cooldown <= 0:
        var player: Node = GameManager.player
        if player and is_instance_valid(player):
            var player_aabb: Rect2 = player._get_aabb()
            var my_aabb := Rect2(global_position.x - size_val / 2, global_position.y - size_val / 2, size_val, size_val)
            if my_aabb.intersects(player_aabb):
                var knockback_dir: Vector2 = (player.global_position - global_position).normalized()
                if knockback_dir == Vector2.ZERO:
                    knockback_dir = Vector2.RIGHT
                player.take_damage(contact_damage, knockback_dir * 200)
                attack_cooldown = 1.0


func set_head(head: bool) -> void:
    is_head = head
    if head:
        if not eye_sprite:
            eye_sprite = ColorRect.new()
            eye_sprite.color = Color(1.0, 0.85, 0.20)
            eye_sprite.size = Vector2(4, 4)
            eye_sprite.position = Vector2(0, -3)
            eye_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
            add_child(eye_sprite)
        contact_damage = boss.HEAD_DAMAGE if boss else 12
        health = boss.HEAD_HP if boss else 80
        max_health = health
    else:
        if eye_sprite:
            eye_sprite.queue_free()
            eye_sprite = null


func take_damage(amount: int, knockback: Vector2) -> void:
    if invuln_timer > 0:
        return
    health -= amount
    damage_flash = 0.2
    invuln_timer = 0.1
    if health <= 0:
        died.emit()
        if boss and boss.has_method("_on_segment_died"):
            boss._on_segment_died(self)
        else:
            queue_free()
