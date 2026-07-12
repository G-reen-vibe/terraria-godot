class_name Arrow
extends Node2D
## A projectile fired by bows. Travels in a direction, damages enemies.

var velocity: Vector2 = Vector2.ZERO
var damage: int = 5
var life_time: float = 0.0
const MAX_LIFE_TIME := 5.0

# Visual
var sprite: ColorRect = null


func _ready() -> void:
    sprite = ColorRect.new()
    sprite.color = Color(0.6, 0.45, 0.25)
    sprite.size = Vector2(12, 2)
    sprite.position = Vector2(-6, -1)
    add_child(sprite)
    set_process(true)


func set_direction(dir: Vector2, speed: float) -> void:
    velocity = dir.normalized() * speed
    rotation = velocity.angle()


func _process(delta: float) -> void:
    life_time += delta
    if life_time > MAX_LIFE_TIME:
        queue_free()
        return

    # Apply gravity (light)
    velocity.y += 100 * delta

    # Move
    var movement := velocity * delta
    var old_pos := global_position
    global_position += movement
    rotation = velocity.angle()

    # Check tile collision
    var world: Node = GameManager.world
    if world:
        var tile := WorldData.world_to_tile_pos(global_position)
        if world.is_solid_at_tile(tile.x, tile.y):
            # Stick in wall
            queue_free()
            return

    # Check enemy collision
    if world:
        for enemy in world.enemies.duplicate():
            if not is_instance_valid(enemy):
                continue
            if not enemy is Node2D:
                continue
            var to_enemy: Vector2 = enemy.global_position - global_position
            if to_enemy.length() < 16:
                if enemy.has_method("take_damage"):
                    enemy.take_damage(damage, velocity.normalized() * 100)
                queue_free()
                return
        # Boss
        if world.boss and is_instance_valid(world.boss):
            var to_boss: Vector2 = world.boss.global_position - global_position
            if to_boss.length() < 32:
                if world.boss.has_method("take_damage"):
                    world.boss.take_damage(damage, velocity.normalized() * 100)
                queue_free()
                return
