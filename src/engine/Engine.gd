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
	
	# Determine execution path

	# In exported builds, res:// is often mapped to the PCK location.
	# We need the directory containing the executable.
	var exec_path = OS.get_executable_path().get_base_dir()
	
	if OS.has_feature("editor"):
		# In editor, use project path but look for binaries in ../bin
		exec_path = ProjectSettings.globalize_path("res://")
		if exec_path.ends_with("/"):
			exec_path = exec_path.substr(0, exec_path.length() - 1)
		# Editor running in src/, binaries are in bin/ (sibling of src)
		# Path should be src/../bin/ -> bin/
		var bin_root = exec_path.get_base_dir() + "/bin"
		print("Editor Mode: Override binary root to ", bin_root)
		# Remap exec_path to bin/linux or bin/windows for loading
		exec_path = bin_root + "/" + bin_subdir
	
	print("Executable path (resolved): ", exec_path)
	
	# Form paths to the executables
	iopiper = exec_path + "/iopiper" + exe_ext
	
	# Try to find Stockfish
	# 1. Look in ./engine/ (relative to executable)
	var engine_dir = exec_path + "/engine/"
	var stockfish_path = engine_dir + stockfish_name
	
	if FileAccess.file_exists(stockfish_path):
		engine_path = stockfish_path
		print("Found Stockfish at: ", stockfish_path)
	elif OS.has_feature("editor"):
		# In editor, might be in custom location? No, we enforced bin/ structure.
		# Check if stockfish is in bin/subdir/engine/
		# The above logic using exec_path should cover it.
		print("Stockfish check in editor mode at: ", stockfish_path)
	else:
		push_warning("Stockfish not found at: " + stockfish_path)

func start_engine():
	if android_plugin:
		print("Starting Android Engine...")
		var success = android_plugin.startEngine()
		return { "started": success, "error": "" if success else "Failed to start" }
		
	if is_web:
		print("Web Engine: Using Mock AI (Random Moves) until WASM is ready.")
		return { "started": true, "error": "" }

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
			# Wait a short moment for the external process (iopiper) to initialize and bind the port
			# This prevents the first packet (uci) from being dropped if sent too quickly
			OS.delay_msec(300)
	
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
		$Timer.start()
	elif is_web:
		# Mock AI for Web: Reply with random move after delay
		if pkt.begins_with("go "):
			# Trigger a fake response
			get_tree().create_timer(1.0).timeout.connect(_on_web_mock_response)
	else:
		$UDPClient.send_packet(pkt)
		$Timer.start()

func _on_web_mock_response():
	# Web fallback: we simulates "bestmove (none)" to trigger Main.gd's fallback logic
	# Main.gd will see this and plays a random legal move if configured.
	emit_signal("done", true, "bestmove (none)")



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
