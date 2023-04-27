extends Node
const ProtocolClass = preload('res://Protocol.gd')
var protocol = ProtocolClass.new()
var socket = WebSocketPeer.new()

var _accum = 0
var _connected = false
var _inited = false;

var nextHeartbeatTimeout = 0
var needSendHeartBeat = false
var curTime = 0

const ERR = 1

var handlerFuncs = {}
var eventFuncs = {}
var requestId = 1
var initCallback: Callable

func init(websocket_url, callback):
	set_process(true)
	initCallback = callback
	return socket.connect_to_url(websocket_url)
	
func _process(delta):
	curTime = curTime + delta
	_readloop(delta)

func close():
	_connected = false
	needSendHeartBeat = false
	_inited = false
	socket.close()
	#socket = WebSocketPeer.new()
	set_process(false)

func _readloop(delta):
	_accum += delta
	if(_accum > 0.2):
		_accum = 0
		socket.poll()
		var state = socket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			if (not _connected):
				_connected = true
				needSendHeartBeat = true
				protocol.handshakeFirst(socket)
			else:
				while socket.get_available_packet_count():
					var outputData = socket.get_packet()
					if not outputData.is_empty():
						_respond(outputData, 0)
		elif state == WebSocketPeer.STATE_CLOSING:
			pass
		elif state == WebSocketPeer.STATE_CLOSED:
			if _connected:
				var code = socket.get_close_code()
				var reason = socket.get_close_reason()
				close()
				var jsonresult = { 'code': code, 'reason': reason }
				if code == 1000:
					var handler = eventFuncs.get('onKick')
					if handler != null: handler.call(jsonresult)
				else:
					var handler = eventFuncs.get('close')
					if handler != null: handler.call(jsonresult)
			
	if curTime >= nextHeartbeatTimeout and needSendHeartBeat:
		protocol.heartBeat(socket)
		needSendHeartBeat = false
	
func _respond(outputData, errCode):
	if(errCode == 0):
		_respondOK(outputData)
	elif(errCode == ERR):
		_respondErr(outputData)

func _respondOK(outputData):
	var msgs = protocol.processPackage(outputData)
	if typeof(msgs) == TYPE_ARRAY:
		for i in range(msgs.size()):
			_handlerWithType(msgs[i].type, msgs[i].body)
	else:
		_handlerWithType(msgs.type, msgs.body)

func _respondErr(outputData):
	print('ERROR: ', outputData)

func _handlerWithType(type, body):
	if type == protocol.TYPE_HANDSHAKE:
		print('handShake: ', PackedByteArray(body).get_string_from_utf8())
		protocol.handshakeACK(socket)
		_inited = true
		initCallback.call()
	elif type == protocol.TYPE_HEARTBEAT:
		print('heartBeat: ', 'get heartbeat')
		needSendHeartBeat = true
		nextHeartbeatTimeout = curTime + 3
	elif type == protocol.TYPE_DATA:
		var result = protocol.decodeMessage(body)
		if result.id > 0 && result.type == protocol.TYPE_RESPONSE:
			var handler = handlerFuncs.get(result.id)
			if handler != null:
				handlerFuncs.erase(result.id)
				var jsonstring = PackedByteArray(result.body).get_string_from_utf8()
				var test_json_conv = JSON.new()
				test_json_conv.parse(jsonstring)
				var jsonresult = test_json_conv.get_data()
				handler.call(jsonresult)
		elif result.type == protocol.TYPE_PUSH:
			var handler = eventFuncs.get(result.route)
			if handler != null:
				var jsonstring = PackedByteArray(result.body).get_string_from_utf8()
				var test_json_conv = JSON.new()
				test_json_conv.parse(jsonstring)
				var jsonresult = test_json_conv.get_data()
				handler.call(jsonresult)

func request(route, msg, callback):
	if not _inited:
		print('ERROR: ', 'Socket inited: false')
		return
	requestId = requestId + 1
	protocol.sendMessage(socket, requestId, route, JSON.stringify(msg))
	handlerFuncs[requestId] = callback
	
func on(route, callback):
	eventFuncs[route] = callback

func off(route):
	eventFuncs.erase(route)

