extends Control

onready var map_bg = $MapBg
#onready var slider_map_size = $SliderMapSize
onready var txt_map_size = $TxtMapSize
onready var tmap_map =$MapBg/TmapMap

const MAP_SIZE_MIN = 10
const MAP_SIZE_MAX = 500

#var map:Array = [[]]
var map_size := MAP_SIZE_MIN*4

func _ready() -> void:
	map_bg.rect_size = Vector2(map_bg.rect_size.y,map_bg.rect_size.y)
	
	txt_map_size.text = String(map_size)

	#slider_map_size.connect("value_changed",self,"_on_SliderMapSize_value_changed")
	txt_map_size.connect("text_changed",self,"_on_TxtMapSize_text_entered")

#func _on_SliderMapSize_value_changed(val:int)->void:
#	pass

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed:
		return
	change_tile(event.global_position)

func change_tile(world_pos:Vector2)->void:
	var tmap_pos = tmap_map.world_to_map(world_pos)
	if tmap_pos.x > map_size || tmap_pos.x < 0 || tmap_pos.y > map_size || tmap_pos.x < 0:
		return
	print("Trying to change tilmap position: ", tmap_pos)

func change_size(new_size:int)->void:
	var map_window_size = map_bg.size.x
	#tmap_map.

func _on_TxtMapSize_text_entered(new_text:String)->void:
	if !new_text.is_valid_integer():
		return
	change_size(int(new_text))