@tool
@icon("res://addons/nested_inventories/icons/ni_item_rect.svg")
class_name NIItemRect
extends Control

const quantity_label_scene: PackedScene = preload("res://addons/nested_inventories/assets/item_quantity_label.tscn")

@export
var connected_item: NIItem:
	set(value):
		connected_item = value
		if !is_node_ready():
			return
		update_texture_rects()
## Use to sync the visuals in the editor with the values of the connected_item.
@export_tool_button("Update preview")
var update_preview_callable: Callable = update_values
## The inventory that the item is contained inside
@export_storage
var connected_inventory: NIInventory
## The position of the item within its inventory
@export_storage
var item_pos: Vector2i
## The texture rects used for both visuals and click-detection
var texture_rects: Array[TextureRect] = []

var NI_HeldItemManager: CanvasLayer

@onready var quantity_label: Label = get_node_or_null("QuantityLabel")
@onready var texture_pivot: Control = get_node_or_null("TexturePivot")

func _ready() -> void:
	if !Engine.is_editor_hint():
		NI_HeldItemManager = get_tree().root.find_child("NIHeldItemManager",false,false)
		assert(NI_HeldItemManager,"Nested Inventories: Missing Autoload! Remember to enable the plugin in the Project Settings")
	
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if !texture_pivot:
		texture_pivot = Control.new()
		texture_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_pivot.name = "TexturePivot"
		add_child(texture_pivot,false,Node.INTERNAL_MODE_FRONT)
	if !quantity_label:
		quantity_label = quantity_label_scene.instantiate()
		quantity_label.name = "QuantityLabel"
		add_child(quantity_label,false,Node.INTERNAL_MODE_FRONT)
	update_values()


func _exit_tree() -> void:
	if !connected_item:
		return
	if connected_item.nested_inventory:
		# Close any container display the nested inventory when this item is removed or picked up
		for container in get_tree().get_nodes_in_group("NIInventoryContainers"):
			if container.connected_inventory == connected_item.nested_inventory:
				container.close_inventory_window()


func update_values() -> void:
	connected_item = connected_item


func update_texture_rects() -> void:
	# Remove the old texture rects so they can be replaced
	for texture_rect in texture_rects:
		texture_rect.queue_free()
	texture_rects.clear()
	# If no item is connected, don't populate any texture_rects
	if !connected_item:
		return
	# The slots that can receive mouse clicks
	var touch_slots: Array[Vector2i] = connected_item.get_relative_slots(Vector2i.ZERO,false)
	var item_bounds: Rect2i = connected_item.get_bounds()
	texture_pivot.rotation = PI/2*connected_item.rotation
	# Accounting for Controls rotating around their top-left corner
	match connected_item.rotation:
		0:texture_pivot.position = Vector2(0,0)
		1:texture_pivot.position = Vector2(connected_item.slot_size.y,0)
		2:texture_pivot.position = connected_item.slot_size
		3:texture_pivot.position = Vector2(0,connected_item.slot_size.x)
	# Loop through every slot position within the bounding rectangle, so that the texture can still be shown in the empty spots.
	for y in range(item_bounds.size.y):
		for x in range(item_bounds.size.x):
			var slot_pos: Vector2i = Vector2i(x,y)
			var item_texture = TextureRect.new()
			item_texture.position = Vector2(slot_pos)*connected_item.slot_size
			# Hook into the gui_input signal to detect mouse clicks
			item_texture.gui_input.connect(_texture_gui_input.bind(slot_pos))
			# Cutting a slot-sized square from the item's sprite, since there are multiple texture rects making up the appearance of the item
			var texture_slice: AtlasTexture = AtlasTexture.new()
			texture_slice.atlas = connected_item.sprite
			texture_slice.region.position = Vector2(slot_pos)*connected_item.slot_size + connected_item.sprite_offset
			texture_slice.region.size = connected_item.slot_size
			item_texture.texture = texture_slice
			item_texture.tooltip_text = connected_item.display_name
			if slot_pos in touch_slots:
				item_texture.mouse_filter = Control.MOUSE_FILTER_PASS
			else:
				# If this slot_pos shouldn't receive mouse clicks, make the texture rect ignore the mouse
				item_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_pivot.add_child(item_texture,false,Node.INTERNAL_MODE_BACK)
			texture_rects.append(item_texture)
	update_quantity_label()


func update_quantity_label() -> void:
	if !connected_item:
		quantity_label.hide()
		return
	# Don't show the quantity label if the item can only stack to 1
	if connected_item.max_quantity == 1:
		quantity_label.hide()
		return
	quantity_label.show()
	quantity_label.text = str(connected_item.quantity)+"/"+str(connected_item.max_quantity)
	# Placing the quantity label on the right-most slot of the bottom row of the item
	quantity_label.position = Vector2(connected_item.get_label_slot())*connected_item.slot_size + connected_item.slot_size
	quantity_label.position -= quantity_label.size


func _texture_gui_input(event: InputEvent, slot: Vector2i) -> void:
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				# The item has been clicked, it should be picked up
				var grab_offset: Vector2 = get_local_mouse_position()
				# Accounting for Controls rotating around their top-left corner
				match connected_item.rotation:
					1: grab_offset -= Vector2(connected_item.slot_size.y,0)
					2: grab_offset -= connected_item.slot_size
					3: grab_offset -= Vector2(0,connected_item.slot_size.x)
				# If there's only one item, the whole stack will always be picked up
				if connected_item.quantity < 2:
					NI_HeldItemManager.pick_up_item(connected_item,get_parent(),slot,grab_offset)
					# Since the whole stack is removed, remove the node from the inventory and queue free it
					if connected_inventory:
						connected_inventory.remove_item_at(item_pos+NestedInventories._rotate_vector2i(connected_item.slots[0],connected_item.rotation))
					queue_free()
					accept_event()
					return
				if Input.is_action_pressed("NITakeHalfItem"):
					# Only half the stack is picked up
					var half_item: NIItem = connected_item.get_duplicate()
					@warning_ignore("integer_division")
					var half_quantity: int = connected_item.quantity/2
					# The stack on the cursor has the larger half if it isn't even
					half_item.quantity -= half_quantity
					connected_item.quantity = half_quantity
					update_quantity_label()
					NI_HeldItemManager.pick_up_item(half_item,get_parent(),slot,grab_offset)
					accept_event()
					return
				if Input.is_action_pressed("NITakeOneItem"):
					# Only one item is picked up from the stack
					var one_item: NIItem = connected_item.get_duplicate()
					one_item.quantity = 1
					connected_item.quantity -= 1
					update_quantity_label()
					NI_HeldItemManager.pick_up_item(one_item,get_parent(),slot,grab_offset)
					accept_event()
					return
				# The whole stack is being picked up
				NI_HeldItemManager.pick_up_item(connected_item,get_parent(),slot,grab_offset)
				# Since the whole stack is removed, remove the node from the inventory and queue free it
				if connected_inventory:
					connected_inventory.remove_item_at(item_pos+NestedInventories._rotate_vector2i(connected_item.slots[0],connected_item.rotation))
				queue_free()
				accept_event()
				return
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if !connected_item.nested_inventory:
					return
				# The item has been right-clicked and has a nested inventory, it should be opened
				var container_pos: Vector2 = global_position
				var item_bounds: Rect2i = connected_item.get_bounds()
				# Making sure the container is lined up with the top-right corner of the item's bounding rectangle
				match connected_item.rotation:
					0: container_pos.x += item_bounds.size.x * connected_item.slot_size.x
					1: container_pos.x += connected_item.slot_size.x
					2: container_pos += Vector2(connected_item.slot_size.x,-(item_bounds.size.y-1)*connected_item.slot_size.y)
					3: container_pos += Vector2(item_bounds.size.y * connected_item.slot_size.y,(item_bounds.size.x-1)*connected_item.slot_size.x)
				# If a container is already open displaying the nested inventory, just move it instead of opening a new one
				for container in get_tree().get_nodes_in_group("NIInventoryContainers"):
					if container.connected_inventory == connected_item.nested_inventory:
						container.global_position = container_pos
						container.move_to_front()
						container.move_contents_to_front()
						return
				# Create a container to display the nested inventory
				var nested_inventory_container: NIInventoryContainer = NIInventoryContainer.new()
				nested_inventory_container.connected_inventory = connected_item.nested_inventory
				get_tree().current_scene.add_child(nested_inventory_container)
				nested_inventory_container.global_position = container_pos
	# Mouse motion is used to avoid a quirk where the MouseButton event for releasing click is received by the control that was initially clicked on, rather than the control that was released on top of
	if event is InputEventMouseMotion:
		if ~event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			if NI_HeldItemManager.mouse_down:
				# An item has been released on this item, it should attempt to stack
				if NI_HeldItemManager.held_item.id != connected_item.id:
					# Not the same id, no stacking
					return
				if connected_item.quantity >= connected_item.max_quantity:
					# Already at max quantity, no stacking
					return
				var combined_quantity: int = connected_item.quantity + NI_HeldItemManager.held_item.quantity
				if combined_quantity <= connected_item.max_quantity:
					# Entire held stack can fit into this stack, remove held stack entirely
					NI_HeldItemManager.delete_held_item()
					connected_item.quantity = combined_quantity
					update_quantity_label()
					accept_event()
				else:
					# Some items remain in held stack, so drop the stack with however much remains
					connected_item.quantity = connected_item.max_quantity
					update_quantity_label()
					NI_HeldItemManager.held_item.quantity = combined_quantity - connected_item.max_quantity
