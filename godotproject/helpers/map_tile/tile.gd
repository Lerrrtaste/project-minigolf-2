extends Area2D

var tile_id := -1

func initiate(id:int,collision_layers:Array)->void:
	tile_id=id
	for i in collision_layers:
		set_collision_layer_bit(i,true)