extends Node2D

onready var map_camera = $MapCam
onready var btn_reset_zoom = $Cam/BtnResetZoom
onready var tmap = $TileMap

var camera_moving := false
var camera_target:Object
var editing_mode := false

var game

func _ready()->void:
	var game = get_node("/root/Game")
	map_camera.make_current()

func editor_set_editing_mode()->void:
	editing_mode = true
	remove_child(map_camera)

func editor_set_tile(tile_id:int,world_pos:Vector2)->void:
	if !editing_mode:
		game.show_error(-1,"editing_mode is not true!")
		return
	var tmap_pos = tmap.world_to_map(world_pos)
	print("Setting tile at pos %s to tileid %s"%[tmap_pos,tile_id])