extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
		pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_Button_pressed():
	#pass # Replace with function body.
	print('_on_Button_pressed')
	Pomelo.init('wss://server.17letui.com:6110', Callable(self, '_do_getConnector'))
	
func _do_getConnector():
	Pomelo.request('gate.gateHandler.getConnector', null, Callable(self, '_on_getConnector'));

func _on_getConnector(response):
	print(response)



func _on_button_2_pressed():
	var ss1 = XlsModule.leixingbiao.getItems()
	print('test1: ', ss1)
	var ss2 = XlsModule.talent.getItem(2)
	print('\n\ntest2: ', ss2)
	
