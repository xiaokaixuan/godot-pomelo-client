extends Node

@export var jsonPath: String = 'res://items.json'

class CTable:
	var table_name = ''
	var values = []
	var values_map = {}
	func _init(_table_name, _values):
		self.table_name = _table_name
		self.values = _values
		for value in self.values:
			values_map[str(value['id'])] = value
	
	func getItems():
		return self.values
	
	func getItem(id):
		return self.values_map.get(str(id))
		

var tables_map = {}
var _property_list = []

func _readJson():
	var file = FileAccess.open(jsonPath, FileAccess.READ)
	var content = file.get_as_text()
	var jsonresult = JSON.parse_string(content)
	for table_name in jsonresult['tables']:
		_property_list.append({
			'name': table_name,
			'class_name': 'CTable',
			'type': TYPE_OBJECT
		})
		tables_map[table_name] = CTable.new(table_name, jsonresult[table_name]['values'])
		
func _get_property_list():
	return _property_list
	
func _get(property):
	return tables_map.get(property)

func _ready():
	return _readJson()
	
	

