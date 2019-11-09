tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("NakamaRestClient", "Node", preload("NakamaRestClient.gd"), preload("icon.png"))

func _exit_tree() -> void:
	remove_custom_type("NakamaRestClient")
