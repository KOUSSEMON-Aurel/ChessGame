extends Node

signal got_packet

var udp := PacketPeerUDP.new()

func set_server(port = 7070):
	var err = udp.connect_to_host('127.0.0.1', port)
	if err != OK:
		push_error("UDP connect_to_host failed with error code: " + str(err))
	else:
		print("UDP connect_to_host successful to 127.0.0.1:" + str(port))

func send_packet(pkt: String):
	var err = udp.put_packet(pkt.to_utf8_buffer())
	if err != OK:
		push_error("UDP put_packet failed with error code: " + str(err))

func _process(_delta):
	while udp.get_available_packet_count() > 0:
		emit_signal('got_packet', udp.get_packet().get_string_from_utf8())
