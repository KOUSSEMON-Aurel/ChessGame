extends Node

signal got_packet

var udp := PacketPeerUDP.new()
var _connected = false

func set_server(port = 7070):
	var err = udp.connect_to_host('127.0.0.1', port)
	if err == OK:
		_connected = true
	else:
		print("UDP Connect Error: ", err)
		_connected = false

func send_packet(pkt: String):
	# Vérifier si l'adresse est configurée pour éviter le crash ERR_UNCONFIGURED
	if _connected:
		udp.put_packet(pkt.to_utf8_buffer())

func _process(_delta):
	# get_available_packet_count peut être appelé même sans connect_to_host (en écoute)
	# Mais ici on est client connecté à host.
	if udp.get_available_packet_count() > 0:
		emit_signal('got_packet', udp.get_packet().get_string_from_utf8())
