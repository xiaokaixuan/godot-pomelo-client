const TYPE_REQUEST = 0
const TYPE_NOTIFY = 1
const TYPE_RESPONSE = 2
const TYPE_PUSH = 3

const PKG_HEAD_BYTES = 4;
const MSG_FLAG_BYTES = 1;
const MSG_ROUTE_CODE_BYTES = 2;
const MSG_ID_MAX_BYTES = 5;
const MSG_ROUTE_LEN_BYTES = 1;

const TYPE_HANDSHAKE = 1
const TYPE_HANDSHAKE_ACK = 2
const TYPE_HEARTBEAT = 3
const TYPE_DATA = 4
const TYPE_KICK = 5

const MSG_COMPRESS_ROUTE_MASK = 0x1;
const MSG_COMPRESS_GZIP_MASK = 0x1;
const MSG_COMPRESS_GZIP_ENCODE_MASK = 1 << 4;
const MSG_TYPE_MASK = 0x7;

const MSG_ROUTE_CODE_MAX = 0xffff;

func encodeMsgFlag(type, compressRoute, buffer, offset):
	if type != TYPE_REQUEST and type != TYPE_NOTIFY and type != TYPE_RESPONSE and type != TYPE_PUSH:
		print("not find type!!")

	if compressRoute:
		buffer[offset] = (type << 1) | 1
	else:
		buffer[offset] = (type << 1) | 0

	return offset + MSG_FLAG_BYTES

func encodeMsgId(id, buffer, offset):
	var tmp = id % 128;
	var next = floor(id/128);

	if next != 0:
		tmp = tmp + 128
	
	buffer[offset] = tmp
	offset = offset + 1
	id = next;
	
	while id != 0:
		tmp = id % 128;
		next = floor(id/128);

		if next != 0:
			tmp = tmp + 128
	
		buffer[offset] = tmp
		offset = offset + 1
		id = next;
	
	return offset

func encodeMsgRoute(compressRoute, route, buffer, offset):
	if compressRoute:
		if route > MSG_ROUTE_CODE_MAX:
			print("route error")
		buffer[offset] = (route >> 8) & 0xff;
		buffer[offset+1] = route & 0xff;
		offset += 2
	else:
		if route:
			var utf8route = route.to_utf8_buffer()
			buffer[offset] = utf8route.size() & 0xff
			offset = offset + 1
			buffer = copyArray(buffer, offset, utf8route, 0, utf8route.size())
			offset = offset + utf8route.size();
		else:
			buffer[offset] = 0
			offset = offset + 1
	
	return offset

func copyArray(buffer, offset, target, start, length):
	for i in range(length):
		buffer[offset + i] = target[start + i]
	return buffer
	
func encodeMsgBody(msg, buffer, offset):
	var utf8msg = msg.to_utf8_buffer()
	buffer = copyArray(buffer, offset, utf8msg, 0, utf8msg.size());
	return offset + utf8msg.size()

func msgHasId(type):
	return type == TYPE_REQUEST || type == TYPE_RESPONSE
 
func msgHasRoute(type):
	return type == TYPE_REQUEST || type == TYPE_NOTIFY || type ==TYPE_PUSH

func caculateMsgIdBytes(id):
	var length = 0
	length += 1
	id >>= 7
	
	while(id > 0):
		length += 1
		id >>= 7
	return length

func encodeMessage(reqId, route, msg):
	var type = TYPE_NOTIFY
	if reqId:
		type = TYPE_REQUEST
		
	var idBytes = 0
	if msgHasId(type):
		idBytes = caculateMsgIdBytes(reqId)
		
	var msgLen = MSG_FLAG_BYTES + idBytes

	if msgHasRoute(type):
		var utf8route = route.to_utf8_buffer()
		msgLen = msgLen + MSG_ROUTE_LEN_BYTES
		msgLen = msgLen + utf8route.size()
	if msg:
		var utf8msg = msg.to_utf8_buffer()
		msgLen = msgLen + utf8msg.size()
		
	var compressRoute = false
	var buffer = Array()
	buffer.resize(msgLen)
	for i in range(msgLen):
		buffer[i] = 0
		
	var offset = 0
	offset = encodeMsgFlag(type, compressRoute, buffer, offset)
	if msgHasId(type):
		offset = encodeMsgId(reqId, buffer, offset)
	if msgHasRoute(type):
		offset = encodeMsgRoute(compressRoute, route, buffer, offset)
	if msg:
		offset = encodeMsgBody(msg, buffer, offset)
	return buffer

func decodeMessage(buffer):
	var bytes = PackedByteArray(buffer)
	var bytesLen = bytes.size()
	var offset = 0
	var id = 0
	var route = null

	var flag = bytes[offset]
	offset += 1
	var compressRoute = flag & MSG_COMPRESS_ROUTE_MASK;
	var type = (flag >> 1) & MSG_TYPE_MASK;
	var compressGzip = (flag >> 4) & MSG_COMPRESS_GZIP_MASK;
	if msgHasId(type):
		var m = 0
		var i = 0
		m = bytes[offset]
		id += (m & 0x7f) << (7 * i)
		offset += 1
		i += 1
		
		while m >= 128:
			m = bytes[offset]
			id += (m & 0x7f) << (7 * i)
			offset += 1
			i += 1
		pass
	if msgHasRoute(type):
		if compressRoute:
			route = (bytes[offset]) << 8 | bytes[offset + 1]
			offset += 2
		else:
			var routeLen = bytes[offset]
			offset += 1
			if routeLen > 0:
				route = bytes.slice(offset, offset + routeLen).get_string_from_utf8()
			else:
				route = ""
			offset += routeLen
	print('route:', route)
	var bodyLen = bytesLen - offset;
	var body = Array()
	body.resize(bodyLen)
	copyArray(body, 0, bytes, offset, bodyLen)
	return {'id': id, 'type': type, 'compressRoute': compressRoute,
			'route': route, 'body': body, 'compressGzip': compressGzip};

func encodePackage(type, body):
	var length = 0
	if body:
		length = body.size()

	var buffer = Array()
	buffer.resize(PKG_HEAD_BYTES + length)
	var index = 0;
	buffer[index] = type & 0xff
	index = index + 1
	buffer[index] = (length >> 16) & 0xff
	index = index + 1
	buffer[index] = (length >> 8) & 0xff
	index = index + 1
	buffer[index] = length & 0xff
	index = index + 1
	
	if body:
		buffer = copyArray(buffer, 4, body, 0, length)
	return buffer;

func decodePackage(buffer):
	var offset = 0
	var bytes = PackedByteArray(buffer)
	var length = 0
	var rs = []
	var size = bytes.size()

	while offset < size:
		var type = bytes[offset]
		var body = null
		length = bytes[offset + 1] << 16 | bytes[offset + 2] << 8 | bytes[offset + 3]
		offset += 4
		if length > 0:
			body = Array()
			body.resize(length)
		
		if body:
			body = copyArray(body, 0, bytes, offset, length)
			
		offset += length

		var package = {"type":type, 
			"body":body
		}
		
		rs.append(package)

	if rs.size() == 1:
		return rs[0]
		
	return rs

const sys = {
	"version": "0.0.1",
	"type": "js-websocket"
	}
	
const request = {
	"sys": sys,
	"user": {}
	}

func heartBeat(socket):
	var obj = encodePackage(TYPE_HEARTBEAT, null)
	socket.put_packet(obj)
	print("send heart beat")

func handshakeFirst(socket):
	var obj = encodePackage(TYPE_HANDSHAKE, JSON.stringify(request).to_utf8_buffer())
	socket.put_packet(obj)

func handshakeACK(socket):
	var obj = encodePackage(TYPE_HANDSHAKE_ACK, null)
	socket.put_packet(obj)

func processPackage(data):
	return decodePackage(data)
	
func handlerWithType(socket, type, body):
	if type == TYPE_HANDSHAKE:
		print('handlerWithType: ', PackedByteArray(body).get_string_from_utf8())
		handshakeACK(socket)
	
	if type == TYPE_DATA:
		decodeMessage(body)

func sendMessage(socket, reqId, route, msg):
	print("sendMessage: ", route)
	var msgEncode = encodeMessage(reqId, route, msg)
	var packet = encodePackage(TYPE_DATA, msgEncode)
	socket.put_packet(packet)

