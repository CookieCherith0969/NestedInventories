extends CanvasLayer


var held_item: NIItem:
	set(value):
		held_item = value
		if held_item:
			held_item_texture.texture = held_item.sprite
		else:
			held_item_texture.texture = null
		held_item_texture.size = Vector2.ZERO
## The node that the held item was a child of. When placed, the item will be a child of this node again.
var item_parent: Node
## Whether the mouse is being held down (while holding an item)
var mouse_down: bool = false
## Which slot the held_item was grabbed on (this is an unrotated value, so it doesn't change when the item rotates)
var grab_slot: Vector2i
## The relative position that the held_item was grabbed from
var grab_offset: Vector2

@onready var held_item_texture: TextureRect = $HeldItemTexture
@onready var quantity_label: Label = $ItemQuantityLabel


func _enter_tree() -> void:
	if !InputMap.has_action("NIRotateItemCCW"):
		InputMap.add_action("NIRotateItemCCW")
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = KEY_Q
		InputMap.action_add_event("NIRotateItemCCW",input_event)
	if !InputMap.has_action("NIRotateItemCW"):
		InputMap.add_action("NIRotateItemCW")
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = KEY_E
		InputMap.action_add_event("NIRotateItemCW",input_event)
	if !InputMap.has_action("NITakeHalfItem"):
		InputMap.add_action("NITakeHalfItem")
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("NITakeHalfItem",input_event)
	if !InputMap.has_action("NITakeOneItem"):
		InputMap.add_action("NITakeOneItem")
		var input_event: InputEventKey = InputEventKey.new()
		input_event.physical_keycode = KEY_CTRL
		InputMap.action_add_event("NITakeOneItem",input_event)


func _process(_delta: float) -> void:
	if held_item:
		held_item_texture.global_position = get_viewport().get_mouse_position()
		held_item_texture.rotation = PI/2*held_item.rotation
		held_item_texture.global_position -= grab_offset
		if held_item.max_quantity == 1:
			quantity_label.hide()
		else:
			quantity_label.show()
			quantity_label.text = str(held_item.quantity)+"/"+str(held_item.max_quantity)
			quantity_label.global_position = held_item_texture.global_position
			var label_slot: Vector2i = held_item.get_label_slot(true)
			quantity_label.position += Vector2(label_slot)*held_item.slot_size + held_item.slot_size
			quantity_label.position -= quantity_label.size
			# Accounting for Controls rotating around their top-left corner
			match held_item.rotation:
				1: quantity_label.position -= Vector2(held_item.slot_size.y,0)
				2: quantity_label.position -= held_item.slot_size
				3: quantity_label.position -= Vector2(0,held_item.slot_size.x)
	else:
		quantity_label.hide()


func _exit_tree() -> void:
	if InputMap.has_action("NIRotateItemCCW"):
		InputMap.erase_action("NIRotateItemCCW")
	if InputMap.has_action("NIRotateItemCW"):
		InputMap.erase_action("NIRotateItemCW")
	if InputMap.has_action("NITakeHalfItem"):
		InputMap.erase_action("NITakeHalfItem")
	if InputMap.has_action("NITakeOneItem"):
		InputMap.erase_action("NITakeOneItem")


func _unhandled_input(event: InputEvent) -> void:
	if !held_item:
		return
	if mouse_down:
		# Mouse motion is used to avoid a quirk where the MouseButton event for releasing click is received by the control that was initially clicked on, rather than the control that was released on top of
		if event is InputEventMouseMotion:
			if ~event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				# Mouse released while holding item
				drop_item_at_cursor()
		elif event.is_action_pressed("NIRotateItemCW"):
			rotate_held_item(1)
		elif event.is_action_pressed("NIRotateItemCCW"):
			rotate_held_item(-1)


func rotate_held_item(rotate_amount: int) -> void:
	if !held_item or !held_item.can_rotate:
		return
	held_item.rotation += rotate_amount
	grab_offset = grab_offset.rotated(PI/2*rotate_amount)

## Set the held_item. parent is the Node that the item will be a child of when placed back into the world. Won't do anything if there's already a held_item.
func pick_up_item(item: NIItem, parent: Node, new_grab_pos: Vector2i, new_grab_offset: Vector2) -> void:
	if held_item:
		return
	held_item = item
	item_parent = parent
	mouse_down = true
	grab_slot = new_grab_pos
	grab_offset = new_grab_offset

## Drop the held_item at a specific location. Won't do anything if there is no held_item.
func drop_item_at(global_pos: Vector2) -> NIItemRect:
	if !held_item:
		return null
	mouse_down = false
	var new_item_rect: NIItemRect = NIItemRect.new()
	new_item_rect.connected_item = held_item
	new_item_rect.global_position = global_pos
	item_parent.add_child(new_item_rect)
	held_item = null
	return new_item_rect

## Drop the held_item at its current location. Won't do anything if there is no held_item.
func drop_item_at_cursor() -> NIItemRect:
	if !held_item:
		return null
	mouse_down = false
	var new_item_rect: NIItemRect = NIItemRect.new()
	new_item_rect.connected_item = held_item
	var drop_pos: Vector2 = get_viewport().get_mouse_position() - grab_offset
	# Accounting for Controls rotating around their top-left corner
	match held_item.rotation:
		1: drop_pos -= Vector2(held_item.slot_size.y,0)
		2: drop_pos -= held_item.slot_size
		3: drop_pos -= Vector2(0,held_item.slot_size.x)
	new_item_rect.global_position = drop_pos
	item_parent.add_child(new_item_rect)
	held_item = null
	return new_item_rect

## Remove the currently held item. The reference is set to null, so the item will be freed if no other references exist.
func delete_held_item() -> void:
	mouse_down = false
	held_item = null
