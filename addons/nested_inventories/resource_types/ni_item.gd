@tool
@icon("res://addons/nested_inventories/icons/ni_item_icon.svg")
class_name NIItem
extends Resource

## Name for display, shouldn't be used for logic
@export
var display_name: String:
	set(value):
		display_name = value
		changed.emit()
## String ID, can be used to determine if two items are the same type even if they're different instances. Should always be set to something.
@export
var id: StringName:
	set(value):
		id = value
		changed.emit()
@export
var sprite: Texture2D:
	set(value):
		sprite = value
		changed.emit()
@export
var sprite_offset: Vector2:
	set(value):
		sprite_offset = value
		changed.emit()
## The slots that make up the item's shape. Can have any arbitrary shape.
@export
var slots: Array[Vector2i] = [Vector2i.ZERO]:
	set(value):
		slots = value
		_sanitise_slots()
		changed.emit()
## The visual size of the slots. Used for sizing and positioning.
@export
var slot_size: Vector2 = Vector2(64,64):
	set(value):
		if value.x < 1 or value.y < 1:
			return
		slot_size = value
		changed.emit()
## The max number of this type of item that can fit in a stack. If set to 1, no quantity label is shown.
@export
var max_quantity: int = 1:
	set(value):
		if value < 1:
			return
		max_quantity = value
		if quantity > max_quantity:
			quantity = max_quantity
		changed.emit()
## The current number of this type of item in the stack. Cannot exceep max_quantity.
@export
var quantity: int = 1:
	set(value):
		if value > max_quantity or value < 1:
			return
		quantity = value
		changed.emit()
## Whether the item can be rotated while being held. Does not stop rotation from being changed in other ways.
@export
var can_rotate: bool = false:
	set(value):
		can_rotate = value
		changed.emit()
## The rotation of the item, stored as an integer number of right-angle clockwise turns.
@export
var rotation: int = 0:
	set(value):
		if value < 0:
			rotation = 3
		elif value > 3:
			rotation = 0
		else:
			rotation = value
		changed.emit()
## The inventory contained within this item. If null, the item contains no inventory.
@export
var nested_inventory: NIInventory = null:
	set(value):
		nested_inventory = value
		changed.emit()

## Gets the list of slots, relative to some starting position. If rotated is true, also rotates the slots (but not the starting position).
func get_relative_slots(pos: Vector2i, rotated: bool = true) -> Array[Vector2i]:
	_sanitise_slots()
	var relative_slots: Array[Vector2i] = []
	for slot in slots:
		if rotated:
			relative_slots.append(pos+NestedInventories._rotate_vector2i(slot,rotation))
		else:
			relative_slots.append(pos+slot)
	return relative_slots

## Gets the right-most slot on the bottom row, ideal for placing a quantity label.
func get_label_slot(rotated: bool = true) -> Vector2i:
	_sanitise_slots()
	var label_slot: Vector2i = Vector2i.ZERO
	var first_value: bool = true
	for slot in get_relative_slots(Vector2i.ZERO,rotated):
		if first_value:
			label_slot = slot
			first_value = false
			continue
		if slot.y > label_slot.y:
			label_slot = slot
		elif slot.y == label_slot.y:
			if slot.x > label_slot.x:
				label_slot = slot
	return label_slot

## Gets the bounding rectangle that encloses every slot of the item.
func get_bounds(rotated: bool = false) -> Rect2i:
	var bound_rect: Rect2i = Rect2i()
	bound_rect.position = Vector2i(0,0)
	var working_slots: Array[Vector2i]
	if rotated:
		working_slots = get_relative_slots(Vector2i.ZERO,true)
	else:
		_sanitise_slots()
		working_slots = slots
	for slot in working_slots:
		var prev_pos: Vector2i = bound_rect.position
		if slot.x < bound_rect.position.x:
			bound_rect.position.x = slot.x
		if slot.y < bound_rect.position.y:
			bound_rect.position.y = slot.y
		bound_rect.end += prev_pos - bound_rect.position
		if slot.x > bound_rect.end.x:
			bound_rect.end.x = slot.x
		if slot.y > bound_rect.end.y:
			bound_rect.end.y = slot.y
	bound_rect.size += Vector2i.ONE
	return bound_rect


func get_duplicate() -> NIItem:
	var new_duplicate: NIItem = NIItem.new()
	new_duplicate.display_name = display_name
	new_duplicate.id = id
	new_duplicate.sprite = sprite.duplicate()
	new_duplicate.sprite_offset = sprite_offset
	_sanitise_slots()
	new_duplicate.slots = slots.duplicate()
	new_duplicate.slot_size = slot_size
	new_duplicate.max_quantity = max_quantity
	new_duplicate.quantity = quantity
	new_duplicate.can_rotate = can_rotate
	new_duplicate.rotation = rotation
	new_duplicate.nested_inventory = nested_inventory
	return new_duplicate

## Used to remove negative-valued slots from the inventory, as they complicate many things.
func _sanitise_slots() -> void:
	for i in range(slots.size()-1,-1,-1):
		if slots[i].x < 0 or slots[i].y < 0:
			push_warning("Item %s(%s) had a negative slot position (%s,%s). It has been automatically removed."%[display_name,id,slots[i].x,slots[i].y])
			slots.remove_at(i)
