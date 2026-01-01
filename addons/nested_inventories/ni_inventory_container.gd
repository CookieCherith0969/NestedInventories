@tool
@icon("res://addons/nested_inventories/ni_inventory_container_icon.svg")
class_name NIInventoryContainer
extends PanelContainer

enum TitleBarMode {DRAG_AND_CLOSE,CLOSE,DRAG,ONLY_TITLE,NO_BAR}

const grid_default_theme: Theme = preload("res://addons/nested_inventories/inventory_grid_theme.tres")

@export
var connected_inventory: NIInventory:
	set(value):
		if connected_inventory:
			connected_inventory.item_removed.disconnect(_on_item_removed)
		connected_inventory = value
		if !is_node_ready():
			return
		if connected_inventory:
			connected_inventory.item_removed.connect(_on_item_removed)
## Changes which controls are available in the title bar. Drag allows the container to be moved by dragging its title bar. Close allows the container to be closed by pressing a close button.
@export
var title_bar_mode: TitleBarMode = TitleBarMode.DRAG_AND_CLOSE:
	set(value):
		title_bar_mode = value
		if !is_node_ready():
			return
		match title_bar_mode:
			TitleBarMode.DRAG_AND_CLOSE:
				title_hbox.show()
				close_button.show()
				drag_bar.show()
			TitleBarMode.CLOSE:
				title_hbox.show()
				close_button.show()
				drag_bar.hide()
			TitleBarMode.DRAG:
				title_hbox.show()
				close_button.hide()
				drag_bar.show()
			TitleBarMode.ONLY_TITLE:
				title_hbox.show()
				close_button.hide()
				drag_bar.hide()
			TitleBarMode.NO_BAR:
				title_hbox.hide()
				close_button.hide()
				drag_bar.hide()
		size = Vector2.ZERO
## Use to sync the visuals in the editor with the values of the connected_inventory.
@export_tool_button("Update Preview")
var update_preview_callable: Callable = update_visuals

var drag_offset: Vector2
var dragging: bool = false
## Panels making up the inventory grid.
var inventory_slots: Array[Control]
## Item Rects container items that are held within this inventory.
var contained_item_rects: Array[NIItemRect]
var NI_HeldItemManager: CanvasLayer

@onready var content_margin: MarginContainer = get_node_or_null("ContentMargin")
@onready var internal_vbox: VBoxContainer = get_node_or_null("ContentMargin/InternalVBox")
@onready var title_hbox: HBoxContainer = get_node_or_null("ContentMargin/InternalVBox/TitleHBox")
@onready var title_label: Label = get_node_or_null("ContentMargin/InternalVBox/TitleHbox/TitleLabel")
@onready var close_button: Button = get_node_or_null("ContentMargin/InternalVBox/TitleHbox/CloseButton")
@onready var drag_bar: Control = get_node_or_null("DragBar")
@onready var inventory_grid: GridContainer = get_node_or_null("ContentMargin/InternalVBox/InventoryGrid")


func _ready() -> void:
	if !Engine.is_editor_hint():
		NI_HeldItemManager = get_tree().root.find_child("NIHeldItemManager",false,false)
		assert(NI_HeldItemManager,"Nested Inventories: Missing Autoload! Remember to enable the plugin in the Project Settings")
	
	if !theme:
		theme = preload("res://addons/nested_inventories/default_inventory_theme.tres").duplicate(true)
	# Group is used for closing/moving inventory containers displaying an item's nested inventory
	if !is_in_group("NIInventoryContainers"):
		add_to_group("NIInventoryContainers",true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if !drag_bar:
		drag_bar = Control.new()
		drag_bar.mouse_filter = Control.MOUSE_FILTER_PASS
		drag_bar.custom_minimum_size.y = 33
		drag_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		drag_bar.gui_input.connect(_on_drag_bar_gui_input)
		drag_bar.name = "DragBar"
		add_child(drag_bar,false,Node.INTERNAL_MODE_FRONT)
	if !content_margin:
		content_margin = MarginContainer.new()
		content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_margin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		content_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		content_margin.add_theme_constant_override("margin_bottom",6)
		content_margin.add_theme_constant_override("margin_left",6)
		content_margin.add_theme_constant_override("margin_right",6)
		content_margin.add_theme_constant_override("margin_top",6)
		content_margin.name = "ContentMargin"
		add_child(content_margin,false,Node.INTERNAL_MODE_FRONT)
	if !internal_vbox:
		internal_vbox = VBoxContainer.new()
		internal_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		internal_vbox.name = "InternalVBox"
		content_margin.add_child(internal_vbox,false,Node.INTERNAL_MODE_FRONT)
	if !title_hbox:
		title_hbox = HBoxContainer.new()
		title_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_hbox.name = "TitleHBox"
		internal_vbox.add_child(title_hbox,false,Node.INTERNAL_MODE_FRONT)
	if !title_label:
		title_label = Label.new()
		title_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		title_label.name = "TitleLabel"
		title_hbox.add_child(title_label,false,Node.INTERNAL_MODE_FRONT)
	if !close_button:
		close_button = Button.new()
		close_button.text = "X"
		close_button.size_flags_horizontal = Control.SIZE_EXPAND + Control.SIZE_SHRINK_END
		close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		close_button.add_theme_font_size_override("font_size",10)
		close_button.pressed.connect(_on_close_button_pressed)
		close_button.name = "CloseButton"
		title_hbox.add_child(close_button,false,Node.INTERNAL_MODE_FRONT)
	if !inventory_grid:
		inventory_grid = GridContainer.new()
		inventory_grid.theme = grid_default_theme
		internal_vbox.add_child(inventory_grid,false,Node.INTERNAL_MODE_FRONT)
	
	if !theme_changed.is_connected(_on_theme_changed):
		theme_changed.connect(_on_theme_changed)
	_on_theme_changed()


func _process(_delta: float) -> void:
	# Making sure the inventory is never bigger than it needs to be
	if content_margin.size.x < size.x:
		size.x = 0
	if content_margin.size.y < size.y:
		size.y = 0
	# The drag bar should always fill the space between the top of the container and the top of the grid of slots
	drag_bar.size.y = inventory_grid.global_position.y - global_position.y
	# Updating to follow the mouse cursor while being dragged
	if dragging:
		global_position = get_global_mouse_position() + drag_offset
	# Making sure the contained items are moving properly with the inventory container
	for i in range(contained_item_rects.size()-1,-1,-1):
		var item: NIItemRect = contained_item_rects[i]
		if item:
			item.global_position = inventory_grid.global_position
			item.global_position += Vector2(item.item_pos)*connected_inventory.slot_size
		else:
			# Cleaning up any references to freed instances
			contained_item_rects.remove_at(i)


func _property_can_revert(property: StringName) -> bool:
	if property == "theme":
		return true
	return false


func _property_get_revert(property: StringName) -> Variant:
	if property == "theme":
		return preload("res://addons/nested_inventories/default_inventory_theme.tres").duplicate(true)
	return null


func update_visuals():
	title_bar_mode = title_bar_mode
	
	# Remove old panels so they can be replaced.
	for slot in inventory_slots:
		slot.queue_free()
	inventory_slots.clear()
	
	# If there's no inventory connected, remove the title and don't populate slots
	if !connected_inventory:
		title_label.text = ""
		return
	title_label.text = connected_inventory.name
	
	var bounds: Rect2i = connected_inventory.get_bounds()
	inventory_grid.columns = bounds.size.x
	var slot_theme: Theme = Theme.new()
	if theme.has_stylebox("panel","NISlotPanel"):
		slot_theme.set_stylebox("panel","Panel",theme.get_stylebox("panel","NISlotPanel"))
	# Loop through every slot position within the bounding rectangle, so that spacers can be added in the empty spots.
	for y in range(bounds.position.y,bounds.end.y):
		for x in range(bounds.position.x,bounds.end.x):
			var slot_pos: Vector2i = Vector2i(x,y)
			# If this slot_pos isn't part of the inventory, place an empty spacer instead of a slot
			if !connected_inventory.valid_slots.has(slot_pos):
				var new_spacer: Control = Control.new()
				new_spacer.custom_minimum_size = connected_inventory.slot_size
				new_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				inventory_grid.add_child(new_spacer,false,Node.INTERNAL_MODE_FRONT)
				inventory_slots.append(new_spacer)
				continue
			
			# If this slot_pos is part of the inventory, set its theme and hook into its signal
			var new_slot: Panel = Panel.new()
			new_slot.custom_minimum_size = connected_inventory.slot_size
			new_slot.mouse_filter = Control.MOUSE_FILTER_PASS
			new_slot.theme = slot_theme
			new_slot.gui_input.connect(_slot_gui_input.bind(slot_pos))
			inventory_grid.add_child(new_slot,false,Node.INTERNAL_MODE_FRONT)
			inventory_slots.append(new_slot)
	
	## Clear out the contained items in the scene, so they can be replaced
	for item_rect in contained_item_rects:
		if item_rect.connected_inventory == connected_inventory:
			item_rect.queue_free()
	contained_item_rects.clear()
	for item in connected_inventory.item_positions:
		var new_item_rect: NIItemRect = NIItemRect.new()
		new_item_rect.connected_inventory = connected_inventory
		new_item_rect.connected_item = item
		var item_pos: Vector2i = connected_inventory.item_positions[item]
		new_item_rect.item_pos = item_pos
		get_tree().current_scene.add_child(new_item_rect)
		contained_item_rects.append(new_item_rect)


func move_contents_to_front() -> void:
	for i in range(contained_item_rects.size()-1,-1,-1):
		if contained_item_rects[i]:
			contained_item_rects[i].move_to_front()
		else:
			# Cleaning up any references to freed instances
			contained_item_rects.remove_at(i)


func close_inventory_window() -> void:
	for item in contained_item_rects:
		if item:
			# Take the items with you
			item.queue_free()
	queue_free()


func _slot_gui_input(event: InputEvent, slot_pos: Vector2i) -> void:
	if !NI_HeldItemManager.held_item:
		return
	# Mouse motion is used to avoid a quirk where the MouseButton event for releasing click is received by the control that was initially clicked on, rather than the control that was released on top of
	if event is InputEventMouseMotion:
		if ~event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if NI_HeldItemManager.mouse_down:
				# A held item has been released on this slot
				# Make sure an item isn't put directly into its own nested inventory
				if NI_HeldItemManager.held_item.nested_inventory == connected_inventory:
					return
				# Accounting for rotation
				var place_pos: Vector2i = slot_pos-NestedInventories._rotate_vector2i(NI_HeldItemManager.grab_slot,NI_HeldItemManager.held_item.rotation)
				# Try to place the item in the inventory. If it fails, then release it outside of any inventory.
				if !connected_inventory.place_item(NI_HeldItemManager.held_item,place_pos):
					NI_HeldItemManager.drop_item_at_cursor()
					return
				
				# Snapping the item to the position of the slot it was placed in
				var drop_pos: Vector2 = global_position
				drop_pos += Vector2(place_pos)*(connected_inventory.slot_size)
				drop_pos += inventory_grid.position
				var new_item_rect: NIItemRect = NI_HeldItemManager.drop_item_at(drop_pos)
				new_item_rect.connected_inventory = connected_inventory
				new_item_rect.item_pos = place_pos
				contained_item_rects.append(new_item_rect)
				# Accept to avoid _unhandled_input() picking up the event
				accept_event()


func _on_drag_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if ~event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if NI_HeldItemManager.mouse_down:
				# Item was released on the drag bar. No special interaction, just drop the item.
				NI_HeldItemManager.drop_item_at_cursor()
			return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_offset = global_position - get_global_mouse_position()
				dragging = true
				# When an inventory container is picked up, it should be on top of other containers and items.
				move_to_front()
				move_contents_to_front()
			else:
				dragging = false


func _on_close_button_pressed() -> void:
	close_inventory_window()


func _on_item_removed(item: NIItem, slot: Vector2i) -> void:
	for i in range(contained_item_rects.size()-1,-1,-1):
		# Making sure no items remain in the array that aren't actually contained in the inventory
		if contained_item_rects[i]:
			if contained_item_rects[i].connected_item == item:
				contained_item_rects.remove_at(i)
		else:
			contained_item_rects.remove_at(i)

## Updates the themes of the internal children to match the custom theme values
func _on_theme_changed():
	if get_theme_stylebox("panel","PanelContainer") != theme.get_stylebox("panel","NIInventoryBackground"):
		add_theme_stylebox_override("panel",theme.get_stylebox("panel","NIInventoryBackground"))
	title_label.add_theme_color_override("font_color",theme.get_color("font_color","NITitleLabel"))
	title_label.add_theme_color_override("font_outline_color",theme.get_color("font_outline_color","NITitleLabel"))
	title_label.add_theme_color_override("font_shadow_color",theme.get_color("font_shadow_color","NITitleLabel"))
	title_label.add_theme_constant_override("line_spacing",theme.get_constant("line_spacing","NITitleLabel"))
	title_label.add_theme_constant_override("outline_size",theme.get_constant("outline_size","NITitleLabel"))
	title_label.add_theme_constant_override("paragraph_spacing",theme.get_constant("paragraph_spacing","NITitleLabel"))
	title_label.add_theme_constant_override("shadow_offset_x",theme.get_constant("shadow_offset_x","NITitleLabel"))
	title_label.add_theme_constant_override("shadow_offset_y",theme.get_constant("shadow_offset_y","NITitleLabel"))
	title_label.add_theme_constant_override("shadow_outline_size",theme.get_constant("shadow_outline_size","NITitleLabel"))
	title_label.add_theme_font_size_override("font_size",theme.get_font_size("font_size","NITitleLabel"))
	title_label.add_theme_font_override("font",theme.get_font("font","NITitleLabel"))
	title_label.add_theme_stylebox_override("focus",theme.get_stylebox("focus","NITitleLabel"))
	title_label.add_theme_stylebox_override("normal",theme.get_stylebox("normal","NITitleLabel"))
	
	close_button.add_theme_color_override("font_color",theme.get_color("font_color","NICloseButton"))
	close_button.add_theme_color_override("font_disabled_color",theme.get_color("font_disabled_color","NICloseButton"))
	close_button.add_theme_color_override("font_focus_color",theme.get_color("font_focus_color","NICloseButton"))
	close_button.add_theme_color_override("font_hover_color",theme.get_color("font_hover_color","NICloseButton"))
	close_button.add_theme_color_override("font_hover_pressed_color",theme.get_color("font_hover_pressed_color","NICloseButton"))
	close_button.add_theme_color_override("font_outline_color",theme.get_color("font_outline_color","NICloseButton"))
	close_button.add_theme_color_override("font_pressed_color",theme.get_color("font_pressed_color","NICloseButton"))
	close_button.add_theme_color_override("icon_disabled_color",theme.get_color("icon_disabled_color","NICloseButton"))
	close_button.add_theme_color_override("icon_focus_color",theme.get_color("icon_focus_color","NICloseButton"))
	close_button.add_theme_color_override("icon_hover_color",theme.get_color("icon_hover_color","NICloseButton"))
	close_button.add_theme_color_override("icon_hover_pressed_color",theme.get_color("icon_hover_pressed_color","NICloseButton"))
	close_button.add_theme_color_override("icon_normal_color",theme.get_color("icon_normal_color","NICloseButton"))
	close_button.add_theme_color_override("icon_pressed_color",theme.get_color("icon_pressed_color","NICloseButton"))
	
	update_visuals()
