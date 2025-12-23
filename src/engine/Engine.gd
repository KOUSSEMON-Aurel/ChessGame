extends Node

class_name UCIEngine

# Provide functionality for interactions with a Chess Engine
# Cross-platform support for Linux, Windows, macOS, Android, and Web

var iopiper # Path to UDP to CLI app bridge in the bin directory
var engine_path # Path to installed Chess Engine in the engine directory
var server_pid = 0
var android_plugin = null
var is_web = false

signal done

func _ready():
	# Detect platform
	var platform = OS.get_name()
	var bin_subdir = ""
	var exe_ext = ""
	var stockfish_name = ""
	
	print("Initializing Engine for platform: ", platform)

	if platform == "Android":
		if Engine.has_singleton("StockfishEngine"):
			android_plugin = Engine.get_singleton("StockfishEngine")
			android_plugin.connect("engine_output", _on_android_engine_output)
			print("Android StockfishEngine plugin found.")
		else:
			push_error("StockfishEngine plugin NOT found on Android!")
		return
		
	if platform == "Web":
		is_web = true
		print("Web platform detected. Engine support limited (WASM required).")
		return
	
	# Desktop Platform-specific configuration
	match platform:
		"Windows":
			bin_subdir = "windows"
			exe_ext = ".exe"
			stockfish_name = "stockfish-windows-x64.exe"
		"Linux", "X11":
			bin_subdir = "linux"
			exe_ext = ""
			stockfish_name = "stockfish-linux-x64"
		"macOS", "OSX":
			bin_subdir = "macos"
			exe_ext = ""
			var output = []
			OS.execute("uname", ["-m"], output)
			var arch = output[0].strip_edges()
			if arch == "arm64":
				stockfish_name = "stockfish-macos-arm64"
			else:
				stockfish_name = "stockfish-macos-x64"
		_:
			push_error("Unsupported platform: " + platform)
			return
	
	# Determine base path
	var base_path = ProjectSettings.globalize_path("res://")
	# In exported builds, res:// is often mapped to the PCK location.
	# We need the directory containing the executable.
	var exec_path = OS.get_executable_path().get_base_dir()
	
	if OS.has_feature("editor"):
		# In editor, use project path
		exec_path = ProjectSettings.globalize_path("res://")
		if exec_path.ends_with("/"):
			exec_path = exec_path.substr(0, exec_path.length() - 1)
	
	print("Executable path: ", exec_path)
	
	# Form paths to the executables
	iopiper = exec_path + "/iopiper" + exe_ext
	
	# Try to find Stockfish
	# 1. Look in ./engine/ (relative to executable)
	var engine_dir = exec_path + "/engine/"
	var stockfish_path = engine_dir + stockfish_name
	
	if FileAccess.file_exists(stockfish_path):
		engine_path = stockfish_path
		print("Found Stockfish at: ", stockfish_path)
	elif FileAccess.file_exists(exec_path + "/" + stockfish_name): # Try root
		engine_path = exec_path + "/" + stockfish_name
		print("Found Stockfish at root: ", engine_path)
	else:
		push_warning("Stockfish not found at: " + stockfish_path)
		# Fallback: search in src/engine for dev mode
		if OS.has_feature("editor"):
			var dev_path = ProjectSettings.globalize_path("res://engine/" + stockfish_name)
			if FileAccess.file_exists(dev_path):
				engine_path = dev_path
				iopiper = ProjectSettings.globalize_path("res://bin/" + bin_subdir + "/iopiper" + exe_ext)
				print("Found Dev Stockfish: ", engine_path)

func start_engine():
	if android_plugin:
		print("Starting Android Engine...")
		var success = android_plugin.startEngine()
		if success:
			print("Android Engine started successfully.")
		else:
			push_error("Failed to start Android Engine.")
		return { "started": success, "error": "" if success else "Failed to start" }
		
	if is_web:
		print("Web Engine not fully implemented.")
		return { "started": false, "error": "Web not supported" }

	return start_udp_server()

func start_udp_server():
	var err = ""
	if !iopiper or !FileAccess.file_exists(iopiper):
		err = "Missing iopiper at: " + str(iopiper)
	elif !engine_path or !FileAccess.file_exists(engine_path):
		err = "Missing chess engine at: " + str(engine_path)
	else:
		print("Starting UDP server...")
		print("  iopiper: ", iopiper)
		print("  engine: ", engine_path)
		server_pid = OS.create_process(iopiper, [engine_path])
		if server_pid < 0:
			err = "Unable to start UDP server."
			server_pid = 0
		else:
			print("UDP server started successfully (PID: ", server_pid, ")")
			$UDPClient.set_server()
	
	if err != "":
		push_error(err)
		
	return { "started": err == "", "error": err }


func stop_engine():
	if android_plugin:
		android_plugin.stopEngine()
	elif server_pid > 0:
		stop_udp_server()

func stop_udp_server():
	var ret_code = 0
	if server_pid > 0:
		print("Stopping UDP server (PID: ", server_pid, ")")
		ret_code = OS.kill(server_pid)
		server_pid = 0
	return ret_code 


func send_packet(pkt: String):
	print("Sent packet: ", pkt)
	if android_plugin:
		android_plugin.sendCommand(pkt)
		# Android plugin uses signal for response, so we start timer for timeout if needed?
		# But usually engine replies fast. 
		# We might need to manually trigger timeout if no response.
		$Timer.start()
	elif is_web:
		pass
	else:
		$UDPClient.send_packet(pkt)
		$Timer.start()


func _on_Timer_timeout():
	# Timeout waiting for response
	# Don't stop engine on timeout, just emit empty
	emit_signal("done", false, "")


func _on_UDPClient_got_packet(pkt):
	$Timer.stop()
	emit_signal("done", true, pkt)

func _on_android_engine_output(pkt):
	$Timer.stop()
	emit_signal("done", true, pkt)

func _on_Engine_tree_exited():
	stop_engine()
