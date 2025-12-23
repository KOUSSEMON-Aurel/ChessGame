extends Node

signal got_packet

var udp := PacketPeerUDP.new()
var _connected = false

func set_server(port = 7070):
	udp.close()
	var err = udp.connect_to_host('127.0.0.1', port)
	if err == OK:
		_connected = true
		print("UDP connect_to_host successful to 127.0.0.1:" + str(port))
	else:
		print("UDP Connect Error: ", err)
		_connected = false

func send_packet(pkt: String):
	if _connected:
		var err = udp.put_packet(pkt.to_utf8_buffer())
		if err != OK:
			push_error("UDP put_packet failed: " + str(err))

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		var pkt = udp.get_packet().get_string_from_utf8()
		emit_signal('got_packet', pkt)
