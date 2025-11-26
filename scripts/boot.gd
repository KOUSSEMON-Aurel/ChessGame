extends Node

func _ready():
	print("🖥️ BOOT SCENE LOADED")
	print("⏳ Waiting 1 second before loading main game...")
	await get_tree().create_timer(1.0).timeout
	print("🔄 Loading main_game.tscn...")
	var err = get_tree().change_scene_to_file("res://main_game.tscn")
	if err != OK:
		print("❌ Failed to change scene: ", err)
