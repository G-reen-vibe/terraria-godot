class_name HUD
extends CanvasLayer
## Heads-up display: hotbar, health/mana bars, inventory window, crafting window

# Hotbar
var hotbar_slots: Array = []
const HOTBAR_SLOT_SIZE := 44
const HOTBAR_SPACING := 4

# Health/mana
var health_bar: ProgressBar = null
var mana_bar: ProgressBar = null
var health_label: Label = null
var mana_label: Label = null

# Inventory panel
var inventory_panel: Panel = null
var inventory_slots: Array = []
var inventory_open: bool = false

# Crafting panel
var crafting_panel: Panel = null
var crafting_list: ItemList = null
var crafting_open: bool = false

# Player reference
var player: Node = null

# Time display
var time_label: Label = null


func _ready() -> void:
    layer = 10
    set_process(true)
    set_process_input(true)
    _build_hotbar()
    _build_health_mana()
    _build_inventory_panel()
    _build_crafting_panel()
    _build_time_label()


func _process(_delta: float) -> void:
    if not player:
        player = GameManager.player
        if player:
            _connect_player_signals()
            _refresh_hotbar()
            _refresh_inventory()
        return
    # Update time label
    if time_label:
        time_label.text = GameManager.format_time() + (" (Day)" if GameManager.is_day() else " (Night)")


func _connect_player_signals() -> void:
    player.health_changed.connect(_on_health_changed)
    player.mana_changed.connect(_on_mana_changed)
    player.inventory_changed.connect(_refresh_inventory)
    player.hotbar_changed.connect(_on_hotbar_changed)
    _on_health_changed(player.health, player.max_health)
    _on_mana_changed(player.mana, player.max_mana)


func _build_hotbar() -> void:
    var container := HBoxContainer.new()
    container.name = "Hotbar"
    container.add_theme_constant_override("separation", HOTBAR_SPACING)
    container.position = Vector2(
        (1280 - (HOTBAR_SLOT_SIZE * 10 + HOTBAR_SPACING * 9)) / 2,
        720 - HOTBAR_SLOT_SIZE - 8
    )
    add_child(container)

    for i in range(10):
        var slot := Panel.new()
        slot.custom_minimum_size = Vector2(HOTBAR_SLOT_SIZE, HOTBAR_SLOT_SIZE)
        slot.name = "Slot%d" % i
        container.add_child(slot)

        # Item icon (color rect for now)
        var icon := ColorRect.new()
        icon.name = "Icon"
        icon.color = Color.TRANSPARENT
        icon.size = Vector2(HOTBAR_SLOT_SIZE - 4, HOTBAR_SLOT_SIZE - 4)
        icon.position = Vector2(2, 2)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(icon)

        # Count label
        var count_label := Label.new()
        count_label.name = "Count"
        count_label.position = Vector2(4, HOTBAR_SLOT_SIZE - 18)
        count_label.add_theme_font_size_override("font_size", 10)
        count_label.add_theme_color_override("font_color", Color.WHITE)
        count_label.add_theme_color_override("font_outline_color", Color.BLACK)
        count_label.add_theme_constant_override("outline_size", 3)
        count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(count_label)

        # Slot number label
        var num_label := Label.new()
        num_label.name = "Number"
        num_label.text = str((i + 1) % 10)
        num_label.position = Vector2(2, 0)
        num_label.add_theme_font_size_override("font_size", 8)
        num_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
        num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(num_label)

        hotbar_slots.append(slot)


func _build_health_mana() -> void:
    # Health hearts (simplified to a bar)
    var hp_container := VBoxContainer.new()
    hp_container.name = "HealthMana"
    hp_container.position = Vector2(8, 8)
    hp_container.add_theme_constant_override("separation", 2)
    add_child(hp_container)

    health_bar = ProgressBar.new()
    health_bar.custom_minimum_size = Vector2(180, 14)
    health_bar.min_value = 0
    health_bar.max_value = 100
    health_bar.value = 100
    health_bar.show_percentage = false
    health_bar.modulate = Color(0.9, 0.3, 0.3)
    hp_container.add_child(health_bar)

    health_label = Label.new()
    health_label.text = "100 / 100"
    health_label.position = Vector2(4, -1)
    health_label.add_theme_font_size_override("font_size", 10)
    health_label.add_theme_color_override("font_color", Color.WHITE)
    health_label.add_theme_color_override("font_outline_color", Color.BLACK)
    health_label.add_theme_constant_override("outline_size", 3)
    health_bar.add_child(health_label)

    mana_bar = ProgressBar.new()
    mana_bar.custom_minimum_size = Vector2(180, 10)
    mana_bar.min_value = 0
    mana_bar.max_value = 20
    mana_bar.value = 20
    mana_bar.show_percentage = false
    mana_bar.modulate = Color(0.3, 0.3, 0.9)
    hp_container.add_child(mana_bar)

    mana_label = Label.new()
    mana_label.text = "20 / 20"
    mana_label.position = Vector2(4, -2)
    mana_label.add_theme_font_size_override("font_size", 9)
    mana_label.add_theme_color_override("font_color", Color.WHITE)
    mana_label.add_theme_color_override("font_outline_color", Color.BLACK)
    mana_label.add_theme_constant_override("outline_size", 2)
    mana_bar.add_child(mana_label)


func _build_inventory_panel() -> void:
    inventory_panel = Panel.new()
    inventory_panel.name = "InventoryPanel"
    inventory_panel.size = Vector2(380, 280)
    inventory_panel.position = Vector2((1280 - 380) / 2, (720 - 280) / 2)
    inventory_panel.visible = false
    add_child(inventory_panel)

    var title := Label.new()
    title.text = "Inventory (E to close)"
    title.position = Vector2(8, 4)
    title.add_theme_font_size_override("font_size", 14)
    inventory_panel.add_child(title)

    # Show slots 10-39 (main inventory, since 0-9 are hotbar)
    var grid := GridContainer.new()
    grid.columns = 10
    grid.position = Vector2(8, 28)
    grid.add_theme_constant_override("h_separation", 2)
    grid.add_theme_constant_override("v_separation", 2)
    inventory_panel.add_child(grid)

    for i in range(30):
        var slot := Panel.new()
        slot.custom_minimum_size = Vector2(32, 32)
        grid.add_child(slot)

        var icon := ColorRect.new()
        icon.name = "Icon"
        icon.color = Color.TRANSPARENT
        icon.size = Vector2(28, 28)
        icon.position = Vector2(2, 2)
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(icon)

        var count_label := Label.new()
        count_label.name = "Count"
        count_label.position = Vector2(4, 14)
        count_label.add_theme_font_size_override("font_size", 9)
        count_label.add_theme_color_override("font_color", Color.WHITE)
        count_label.add_theme_color_override("font_outline_color", Color.BLACK)
        count_label.add_theme_constant_override("outline_size", 2)
        count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(count_label)

        inventory_slots.append(slot)

    # Equipment section
    var equip_title := Label.new()
    equip_title.text = "Armor:"
    equip_title.position = Vector2(8, 200)
    equip_title.add_theme_font_size_override("font_size", 12)
    inventory_panel.add_child(equip_title)


func _build_crafting_panel() -> void:
    crafting_panel = Panel.new()
    crafting_panel.name = "CraftingPanel"
    crafting_panel.size = Vector2(360, 380)
    crafting_panel.position = Vector2((1280 - 360) / 2, (720 - 380) / 2)
    crafting_panel.visible = false
    add_child(crafting_panel)

    var title := Label.new()
    title.text = "Crafting (C to close)"
    title.position = Vector2(8, 4)
    title.add_theme_font_size_override("font_size", 14)
    crafting_panel.add_child(title)

    crafting_list = ItemList.new()
    crafting_list.position = Vector2(8, 28)
    crafting_list.size = Vector2(344, 320)
    crafting_panel.add_child(crafting_list)

    var craft_btn := Button.new()
    craft_btn.text = "Craft"
    craft_btn.position = Vector2(8, 354)
    craft_btn.size = Vector2(344, 22)
    craft_btn.pressed.connect(_on_craft_button)
    crafting_panel.add_child(craft_btn)


func _build_time_label() -> void:
    time_label = Label.new()
    time_label.name = "TimeLabel"
    time_label.text = "Time"
    time_label.position = Vector2(8, 36)
    time_label.add_theme_font_size_override("font_size", 12)
    time_label.add_theme_color_override("font_color", Color.WHITE)
    time_label.add_theme_color_override("font_outline_color", Color.BLACK)
    time_label.add_theme_constant_override("outline_size", 3)
    add_child(time_label)


func _on_health_changed(hp: int, max_hp: int) -> void:
    if health_bar:
        health_bar.max_value = max_hp
        health_bar.value = hp
    if health_label:
        health_label.text = "%d / %d" % [hp, max_hp]


func _on_mana_changed(m: int, max_m: int) -> void:
    if mana_bar:
        mana_bar.max_value = max_m
        mana_bar.value = m
    if mana_label:
        mana_label.text = "%d / %d" % [m, max_m]


func _on_hotbar_changed(index: int) -> void:
    _refresh_hotbar()


func _refresh_hotbar() -> void:
    if not player:
        return
    for i in range(10):
        var slot: Panel = hotbar_slots[i]
        var icon: ColorRect = slot.get_node("Icon")
        var count_label: Label = slot.get_node("Count")
        var item = player.inventory[i]
        if item and typeof(item) == TYPE_DICTIONARY:
            var item_data: Dictionary = ItemDB.get_item(item.get("id", ""))
            icon.color = item_data.get("icon_color", Color.MAGENTA)
            if item.get("count", 0) > 1:
                count_label.text = str(item.get("count", 0))
            else:
                count_label.text = ""
        else:
            icon.color = Color.TRANSPARENT
            count_label.text = ""
        # Highlight selected slot
        if i == player.hotbar_index:
            slot.modulate = Color(1.3, 1.3, 1.3, 1.0)
        else:
            slot.modulate = Color.WHITE


func _refresh_inventory() -> void:
    if not player:
        return
    _refresh_hotbar()
    for i in range(30):
        var slot: Panel = inventory_slots[i]
        var icon: ColorRect = slot.get_node("Icon")
        var count_label: Label = slot.get_node("Count")
        var item = player.inventory[i + 10]  # main inventory starts at slot 10
        if item and typeof(item) == TYPE_DICTIONARY:
            var item_data: Dictionary = ItemDB.get_item(item.get("id", ""))
            icon.color = item_data.get("icon_color", Color.MAGENTA)
            if item.get("count", 0) > 1:
                count_label.text = str(item.get("count", 0))
            else:
                count_label.text = ""
        else:
            icon.color = Color.TRANSPARENT
            count_label.text = ""


func toggle_inventory() -> void:
    inventory_open = not inventory_open
    inventory_panel.visible = inventory_open
    if inventory_open:
        _refresh_inventory()
    if player:
        player.inventory_ui_open = inventory_open


func toggle_crafting() -> void:
    crafting_open = not crafting_open
    crafting_panel.visible = crafting_open
    if crafting_open:
        _refresh_crafting()
    if player:
        player.crafting_ui_open = crafting_open


func _refresh_crafting() -> void:
    if not player:
        return
    crafting_list.clear()
    # Get nearby stations
    var stations: Array = []
    if GameManager.world and GameManager.world.has_method("get_nearby_stations"):
        stations = GameManager.world.get_nearby_stations(player.global_position)
    var recipes: Array = RecipeDB.get_available_recipes(player.inventory, stations)
    for recipe in recipes:
        var item_data: Dictionary = ItemDB.get_item(recipe.get("result", ""))
        var name: String = item_data.get("name", recipe.get("result", ""))
        var text := "%s x%d" % [name, recipe.get("count", 1)]
        # Add ingredients
        var ings := " ("
        for ing in recipe.get("ingredients", []):
            var ing_data: Dictionary = ItemDB.get_item(ing.get("id", ""))
            ings += "%s x%d, " % [ing_data.get("name", ing.get("id", "")), ing.get("count", 0)]
        ings = ings.substr(0, ings.length() - 2) + ")"
        text += " " + ings
        crafting_list.add_item(text)
        # Set metadata
        var idx: int = crafting_list.item_count - 1
        crafting_list.set_item_metadata(idx, recipe)


func _on_craft_button() -> void:
    if not player:
        return
    var selected: Array = crafting_list.get_selected_items()
    if selected.size() == 0:
        return
    var recipe: Dictionary = crafting_list.get_item_metadata(selected[0])
    if recipe.is_empty():
        return
    if RecipeDB.can_craft(recipe, player.inventory, GameManager.world.get_nearby_stations(player.global_position)):
        player.inventory = RecipeDB.consume_ingredients(player.inventory, recipe)
        player._add_item(recipe.get("result", ""), recipe.get("count", 1))
        _refresh_crafting()
        _refresh_inventory()


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.physical_keycode == KEY_E:
            toggle_inventory()
        elif event.physical_keycode == KEY_C:
            toggle_crafting()
        elif event.physical_keycode == KEY_ESCAPE:
            if crafting_open:
                toggle_crafting()
            elif inventory_open:
                toggle_inventory()
