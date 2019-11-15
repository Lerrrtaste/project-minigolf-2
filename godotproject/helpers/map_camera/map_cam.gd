extends Camera2D

var dragable := true
var zoomable := true
var target:Object

var camera_moving := false

func _process(delta: float) -> void:
	if target != null: #TODO activate margin + smooth movement when following target
		global_position = target.global_position

func _input(event: InputEvent) -> void:
	if dragable:
		if event.is_action_pressed("camera_move"): # TODO maybe set camera_target to null if not done elsewhere after ball finished moving
			camera_moving = true
		
		if event.is_action_released("camera_move"):
			camera_moving = false
		
		if event is InputEventMouseMotion:
			if camera_moving:
				global_position -= event.relative
	
	if zoomable:
		if event.is_action_pressed("camera_zoom_in"):
			zoom -= Vector2(0.05,0.05)
	
		if event.is_action_pressed("camera_zoom_out"):
			zoom += Vector2(0.05,0.05)