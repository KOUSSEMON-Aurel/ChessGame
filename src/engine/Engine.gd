extends Node

class_name UCIEngine

# Provide functionality for interactions with a Chess Engine
# Cross-platform support for Linux, Windows, macOS, AND Web via Stockfish.js, AND Android via Plugin

var iopiper # Path to UDP to CLI app bridge in the bin directory
var engine # Path to installed Chess Engine in the engine directory
var server_pid = 0

# Web specific variables
var _web_worker: JavaScriptObject
var _js_callback: JavaScriptObject
var _js_error_callback: JavaScriptObject

# Android specific variables
var _android_plugin: Object
var _android_started = false

signal done

func _ready():
	# Check for Web export
	if OS.has_feature("web"):
		print("Detected platform: Web (using Stockfish.js)")
		return

	# Check for Android export
	if OS.get_name() == "Android":
		print("Detected platform: Android (using StockfishEngine Plugin)")
		if Engine.has_singleton("StockfishEngine"):
			_android_plugin = Engine.get_singleton("StockfishEngine")
			_android_plugin.connect("engine_output", _on_android_engine_output)
			print("StockfishEngine singleton found and connected.")
		else:
			push_error("StockfishEngine singleton NOT found. Make sure the plugin is enabled in export preset.")
		# Do NOT return immediately if we want generic init? 
		# Actually Main.gd handles init via start_udp_server call if is_engine_ready returns false.
		return

	# Detect desktop platform

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

	# Desktop/other platforms: Determine paths from base_path
	# Get the base path of the application
	var base_path = ""
	
	if OS.has_feature("editor"):
		# In editor, use globalize_path and strip "src" if needed
		base_path = ProjectSettings.globalize_path("res://")
		# Remove trailing slash if present
		if base_path.ends_with("/") or base_path.ends_with("\\"):
			base_path = base_path.substr(0, base_path.length() - 1)
		
		# Check if we're running from the src directory (development mode)
		var src_pos = base_path.find("src")
		if src_pos > -1:
			base_path = base_path.substr(0, src_pos - 1)
	else:
		# In export, binaries are relative to the executable
		base_path = OS.get_executable_path().get_base_dir()

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
	# Web Logic
	if OS.has_feature("web"):
		return _init_web_engine()

	# Android Logic
	if OS.get_name() == "Android":
		if _android_plugin:
			var success = _android_plugin.startEngine()
			if success:
				print("Android Stockfish Engine started.")
				_android_started = true
				return { "started": true, "error": "" }
			else:
				return { "started": false, "error": "Failed to start Android Stockfish Engine" }
		else:
			return { "started": false, "error": "Android Plugin not initialized" }

	# Desktop Logic
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


func _init_web_engine():
	if _web_worker:
		return { "started": true, "error": "" }

	if not JavaScriptBridge:
		return { "started": false, "error": "JavaScriptBridge not available" }

	print("Initializing Stockfish.js Worker...")
	# Create Worker. path must be relative to index.html or absolute URL
	_web_worker = JavaScriptBridge.create_object("Worker", "stockfish.js")
	
	if not _web_worker:
		return { "started": false, "error": "Failed to create Worker('stockfish.js'). Make sure the file exists." }

	# Create callback for onmessage
	_js_callback = JavaScriptBridge.create_callback(_on_js_message)
	_web_worker.set("onmessage", _js_callback)
	
	# Add error handler
	_js_error_callback = JavaScriptBridge.create_callback(_on_js_error)
	_web_worker.set("onerror", _js_error_callback)
	
	print("Stockfish.js Worker initialized.")
	return { "started": true, "error": "" }

func _on_js_error(args):
	print("JS WORKER ERROR: ", args)

func _on_js_message(args):
	# args[0] is the MessageEvent
	if args and args.size() > 0:
		var event = args[0]
		# Use direct property access. .get("data") fails because it tries to call JS function "get".
		var data = event.data 
		print("JS << ", data)
		$Timer.stop()
		# Only emit if actual data
		if data != null:
			emit_signal("done", true, str(data))


func is_engine_ready() -> bool:
	"""Check if the engine is ready (Desktop: process running, Web: worker created)."""
	if OS.has_feature("web"):
		return _web_worker != null
	elif OS.get_name() == "Android":
		return _android_plugin != null and _android_started
	else:
		return server_pid > 0


func stop_udp_server():
	# Web Cleanup
	if OS.has_feature("web"):
		if _web_worker:
			_web_worker.terminate()
			_web_worker = null
		return 0
		
	# Android Cleanup
	if OS.get_name() == "Android":
		if _android_plugin:
			_android_plugin.stopEngine()
		_android_started = false
		return 0

	# Desktop Cleanup
	# Return 0 or an error code
	var ret_code = 0
	if server_pid > 0:
		print("Stopping UDP server (PID: ", server_pid, ")")
		ret_code = OS.kill(server_pid)
		server_pid = 0
	return ret_code 


func send_packet(pkt: String):
	print("Sent packet: ", pkt)
	
	if OS.has_feature("web"):
		if _web_worker:
			_web_worker.postMessage(pkt)
			$Timer.start()
		else:
			print("Error: Web Worker not initialized")
	elif OS.get_name() == "Android":
		if _android_plugin:
			_android_plugin.sendCommand(pkt)
			$Timer.start()
		else:
			print("Error: Android Plugin not initialized")
	else:
		$UDPClient.send_packet(pkt)
		$Timer.start()


func _on_Timer_timeout():
	if OS.has_feature("web"):
		print("Web Worker timeout (command didn't reply in time). Not killing worker.")
		# Don't kill the worker, it might be thinking deep.
		# But we still need to signal that this specific synchronous command "failed" or finished?
		# Actually, Stockfish sends "bestmove" eventually.
		# If this is "isready", it should answer fast.
		pass
	elif OS.get_name() == "Android":
		print("Android timeout. Engine might be thinking or dead.")
		pass
	else:
		stop_udp_server() 
	emit_signal("done", false, "")


func _on_UDPClient_got_packet(pkt):
	$Timer.stop()
	emit_signal("done", true, pkt)

func _on_android_engine_output(output):
	# Treat Android output the same as UDP output
	_on_UDPClient_got_packet(output)

func _on_Engine_tree_exited():
	stop_udp_server()
