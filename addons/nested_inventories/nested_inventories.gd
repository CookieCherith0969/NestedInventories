@tool
class_name NestedInventories
extends EditorPlugin

const AUTOLOAD_NAME: String = "NIHeldItemManager"
const AUTOLOAD_PATH: String = "res://addons/nested_inventories/autoloads/ni_held_item_manager.tscn"


# Used by some scripts in the plugin when handling rotated items
static func _rotate_vector2i(value: Vector2i, rotation_index: int) -> Vector2i:
	rotation_index = posmod(rotation_index,4)
	match rotation_index:
		0:
			return value
		1:
			return Vector2i(-value.y,value.x)
		2:
			return Vector2i(-value.x,-value.y)
		3:
			return Vector2i(value.y,-value.x)
	return value


func _enable_plugin() -> void:
	# Add autoloads here.
	add_autoload_singleton(AUTOLOAD_NAME,AUTOLOAD_PATH)


func _disable_plugin() -> void:
	# Remove autoloads here.
	remove_autoload_singleton(AUTOLOAD_NAME)
