@tool
@icon("res://addons/nested_inventories/icons/ni_inventory_icon.svg")
class_name NIInventory
extends Resource

signal item_removed(item: NIItem, slot: Vector2i)
signal item_added(item: NIItem, slot: Vector2i)

@export
var name: String:
	set(value):
		name = value
		changed.emit()
## The slots that make up the inventory. Can have any arbitrary shape.
@export
var valid_slots: Array[Vector2i]:
	set(value):
		valid_slots = value
		changed.emit()
## The visual size of the slots in this inventory, used for spacing and sizing.
@export
var slot_size: Vector2 = Vector2(64,64):
	set(value):
		slot_size = value
		changed.emit()
## A map from occuplied slots, to the items that are occupying them.
@export_storage
var occupied_slots: Dictionary[Vector2i,NIItem]
## A map from items, to the position of their (0,0) slots.
@export_storage
var item_positions: Dictionary[NIItem,Vector2i]

## Returns true if the slot at slot_pos is both part of the inventory, and not occupied by an item. Otherwise returns false.
func is_slot_open(slot_pos: Vector2i) -> bool:
	if !valid_slots.has(slot_pos):
		return false
	if occupied_slots.has(slot_pos):
		return false
	return true

## Get the item at the slot_pos, if one is there. Otherwise returns null.
func get_item_at(slot_pos: Vector2i) -> NIItem:
	if occupied_slots.has(slot_pos):
		return occupied_slots[slot_pos]
	return null

## Check if an item can fit in a specified location. The place_pos is the (0,0) slot of the item.
func can_place_item(item: NIItem, place_pos: Vector2i) -> bool:
	var item_slots: Array[Vector2i] = item.get_relative_slots(place_pos)
	for item_slot in item_slots:
		if !is_slot_open(item_slot):
			return false
	return true

## Place an item at the specified location. The place_pos is the (0,0) slot of the item. Produces a warning if the item cannot fit there.
func place_item(item: NIItem, place_pos: Vector2i) -> bool:
	if !can_place_item(item, place_pos):
		push_warning("Tried to place item in invalid position")
		return false
	item_positions[item] = place_pos
	
	var item_slots: Array[Vector2i] = item.get_relative_slots(place_pos)
	
	for item_slot in item_slots:
		occupied_slots[item_slot] = item
	item_added.emit(item, place_pos)
	return true

## Remove the item at the specified location. Produces a warning if no item is there.
func remove_item_at(remove_pos: Vector2i) -> bool:
	if !occupied_slots.has(remove_pos):
		push_warning("Tried to remove item where no item exists")
		return false
	var remove_item: NIItem = occupied_slots[remove_pos]
	var item_pos: Vector2i = item_positions[remove_item]
	var item_slots: Array[Vector2i] = remove_item.get_relative_slots(item_pos)
	
	for item_slot in item_slots:
		occupied_slots.erase(item_slot)
	item_positions.erase(remove_item)
	item_removed.emit(remove_item,item_pos)
	return true

## Get the bounding Rect that fits all of the inventory's slots
func get_bounds() -> Rect2i:
	if valid_slots.is_empty():
		push_warning("Got bounds of inventory with no slots")
		return Rect2i()
	var bound_rect: Rect2i = Rect2i()
	bound_rect.position = valid_slots[0]
	for valid_slot in valid_slots:
		if valid_slot.x < bound_rect.position.x:
			bound_rect.position.x = valid_slot.x
		if valid_slot.y < bound_rect.position.y:
			bound_rect.position.y = valid_slot.y
		if valid_slot.x > bound_rect.end.x:
			bound_rect.end.x = valid_slot.x
		if valid_slot.y > bound_rect.end.y:
			bound_rect.end.y = valid_slot.y
	bound_rect.size += Vector2i.ONE
	return bound_rect


## Get the list of slots, sorting in reading order
func get_ordered_slots() -> Array[Vector2i]:
	valid_slots.sort_custom(_slot_sort)
	return valid_slots


func _to_string() -> String:
	var str_rep: String = ""
	var bound_rect: Rect2i = get_bounds()
	for y in range(bound_rect.position.y,bound_rect.end.y+1):
		for x in range(bound_rect.position.x,bound_rect.end.x+1):
			var slot_pos: Vector2i = Vector2i(x,y)
			if !valid_slots.has(slot_pos):
				str_rep += "   "
				continue
			str_rep += "["
			if occupied_slots.has(slot_pos):
				str_rep += occupied_slots[slot_pos].id
			else:
				str_rep += " "
			str_rep += "]"
		str_rep += "\n"
	return str_rep

## Sorting function that places positions in "reading order" (left-to-right, top-to-bottom)
func _slot_sort(a: Vector2i, b: Vector2i) -> bool:
	if a.y < b.y:
		return true
	if b.y < a.y:
		return false
	if a.x < b.x:
		return true
	return false
