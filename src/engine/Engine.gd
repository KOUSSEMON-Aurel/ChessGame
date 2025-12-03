extends Node

class_name UCIEngine

# Provide functionality for interactions with a Chess Engine
# Cross-platform support for Linux, Windows, and macOS

var iopiper # Path to UDP to CLI app bridge in the bin directory
var engine # Path to installed Chess Engine in the engine directory
var server_pid = 0

signal done

func _ready():
	# Detect platform
	var platform = OS.get_name()
	var bin_subdir = ""
	var exe_ext = ""
	var stockfish_name = ""
	
	# Platform-specific configuration
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
			# Detect macOS architecture
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
	
	print("Detected platform: ", platform, " (bin subdir: ", bin_subdir, ")")
	
	# Get the base path of the application
	# Use ProjectSettings to get the correct resource path
	var base_path = ProjectSettings.globalize_path("res://")
	
	# Remove trailing slash if present
	if base_path.ends_with("/") or base_path.ends_with("\\"):
		base_path = base_path.substr(0, base_path.length() - 1)
	
	# Check if we're running from the src directory (development mode)
	var src_pos = base_path.find("src")
	if src_pos > -1:
		base_path = base_path.substr(0, src_pos - 1)
	
	print("Base path: ", base_path)
	
	# Form paths to the executables
	# Use forward slash for consistency (works on all platforms)
	iopiper = base_path + "/bin/" + bin_subdir + "/iopiper" + exe_ext
	
	# Try to find Stockfish in the engine directory
	var engine_dir = base_path + "/engine/"
	var stockfish_path = engine_dir + stockfish_name
	
	# First, try the platform-specific stockfish name
	if FileAccess.file_exists(stockfish_path):
		engine = stockfish_path
		print("Found Stockfish: ", stockfish_path)
	else:
		# Fallback: search for any stockfish executable in the engine directory
		print("Platform-specific Stockfish not found at: ", stockfish_path)
		print("Searching for any Stockfish binary in: ", engine_dir)
		
		var dir = DirAccess.open(engine_dir)
		if dir != null:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				# Look for files starting with "stockfish" that are not directories
				if file_name.begins_with("stockfish") and not dir.current_is_dir():
					var candidate = engine_dir + file_name
					# Skip .tar, .zip, .gz files
					if not file_name.ends_with(".tar") and not file_name.ends_with(".zip") and not file_name.ends_with(".gz"):
						engine = candidate
						print("Found Stockfish: ", candidate)
						break
				file_name = dir.get_next()
			dir.list_dir_end()
	
	if engine == null or engine == "":
		push_warning("Stockfish engine not found in: " + engine_dir)
		push_warning("Please run setup.sh (Linux/Mac) or setup.bat (Windows) to download Stockfish")


func start_udp_server():
	var err = ""
	# Check for existence of the executables
	if !FileAccess.file_exists(iopiper):
		err = "Missing iopiper at: " + iopiper + "\nPlease run the setup script for your platform."
	elif !FileAccess.file_exists(engine):
		err = "Missing chess engine at: " + str(engine) + "\nPlease run the setup script for your platform."
	else:
		print("Starting UDP server...")
		print("  iopiper: ", iopiper)
		print("  engine: ", engine)
		server_pid = OS.create_process(iopiper, [engine])
		if server_pid < 400: # PIDs are likely above this value and error codes below it
			err = "Unable to start UDP server with error code: " + str(server_pid)
			server_pid = 0
		else:
			print("UDP server started successfully (PID: ", server_pid, ")")
			$UDPClient.set_server()
	return { "started": err == "", "error": err }


func stop_udp_server():
	# Return 0 or an error code
	var ret_code = 0
	if server_pid > 0:
		print("Stopping UDP server (PID: ", server_pid, ")")
		ret_code = OS.kill(server_pid)
		server_pid = 0
	return ret_code 


func send_packet(pkt: String):
	print("Sent packet: ", pkt)
	$UDPClient.send_packet(pkt)
	$Timer.start()


func _on_Timer_timeout():
	stop_udp_server()
	emit_signal("done", false, "")


func _on_UDPClient_got_packet(pkt):
	$Timer.stop()
	emit_signal("done", true, pkt)


func _on_Engine_tree_exited():
	stop_udp_server()
