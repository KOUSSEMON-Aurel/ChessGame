extends Control

func _on_Start_pressed():
	var status = $Engine.start_engine()
	if status.started:
		print("Wrapper started!")
		await get_tree().idle_frame
		$Engine.send_packet("uci")
	else:
		print(status.error)


func _on_Engine_done(ok, packet):
	print(ok, "\t", packet)
	if packet == "uciok":
		print("OK")
