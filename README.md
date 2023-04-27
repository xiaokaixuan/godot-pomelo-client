# godot-pomelo-client

## Usage

```GDScript

func _on_Button_pressed():
	# 初始化连接
	print('_on_Button_pressed')
	Pomelo.init('wss://xxx.17xxx.com:6200', Callable(self, '_do_getConnector'))
	
func _do_getConnector():
	# 事件处理
	Pomelo.on('onKick', Callable(self, '_on_Kick'))
	Pomelo.on('close', Callable(self, '_on_Close'))
	# 登陆
	Pomelo.request('connector.entryHandler.login', { '_id': 'xxxxxx' }, Callable(self, '_on_getConnector'));

func _on_getConnector(response):
	# 登陆回调
	print(response)

func _on_button_2_pressed():
	var ss1 = XlsModule.leixingbiao.getItems()
	print('test1: ', ss1)
	var ss2 = XlsModule.talent.getItem(2)
	print('\n\ntest2: ', ss2)
	
func _on_Kick(response):
	# 剔出处理
	print('onKick: ', response)

func _on_Close(response):
	# 断线处理
	print('onClose: ', response)
	
	
```
