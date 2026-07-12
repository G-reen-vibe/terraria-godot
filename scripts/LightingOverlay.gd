class_name LightingOverlay
extends Node2D
## Draws darkness over the world based on the World's light grid.
## This node should be a child of the World node.

var world: Node = null  # Reference to World node


func _ready() -> void:
        z_index = 100  # Above most things
        # Find the world parent
        world = get_parent()
        while world and not world.has_method("get_tile"):
                world = world.get_parent()
        set_process(true)


func _draw() -> void:
        if not world or not ("light_grid" in world):
                return
        var view_rect: Rect2 = get_viewport_rect()
        # Convert screen rect to world coords
        var canvas_transform := get_canvas_transform()
        var origin := canvas_transform.get_origin()
        var scale_v := canvas_transform.get_scale()
        view_rect = Rect2(
                -origin / scale_v,
                view_rect.size / scale_v
        )

        # Determine which light cells are visible
        var LIGHT_CELL_SIZE: int = world.LIGHT_CELL_SIZE
        var lg_w: int = world.light_grid_w
        var lg_h: int = world.light_grid_h

        var tx0: int = max(0, int(view_rect.position.x / (WorldData.TILE_SIZE * LIGHT_CELL_SIZE)))
        var ty0: int = max(0, int(view_rect.position.y / (WorldData.TILE_SIZE * LIGHT_CELL_SIZE)))
        var tx1: int = min(lg_w - 1, int((view_rect.position.x + view_rect.size.x) / (WorldData.TILE_SIZE * LIGHT_CELL_SIZE)))
        var ty1: int = min(lg_h - 1, int((view_rect.position.y + view_rect.size.y) / (WorldData.TILE_SIZE * LIGHT_CELL_SIZE)))

        # Draw darkness rectangles - use a darker tint at night for ambient
        var night_factor := 1.0
        if GameManager:
                # Even with lights, night should darken the sky background a bit
                night_factor = 0.7 if GameManager.is_night() else 0.4

        # Draw cells
        for ly in range(ty0, ty1 + 1):
                for lx in range(tx0, tx1 + 1):
                        var dark: int = world.light_grid[ly][lx]
                        if dark <= 0:
                                continue
                        var alpha: float = clamp(dark / 15.0, 0.0, 1.0) * 0.93
                        var rect := Rect2(
                                lx * WorldData.TILE_SIZE * LIGHT_CELL_SIZE,
                                ly * WorldData.TILE_SIZE * LIGHT_CELL_SIZE,
                                WorldData.TILE_SIZE * LIGHT_CELL_SIZE,
                                WorldData.TILE_SIZE * LIGHT_CELL_SIZE
                        )
                        draw_rect(rect, Color(0.0, 0.0, 0.02, alpha))


func _process(_delta: float) -> void:
        queue_redraw()
