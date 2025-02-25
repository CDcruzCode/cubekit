extends Control

@export var TITLE:String
@export var TITLE_PREFIX:String = "%"
@export var BG_COLOUR:Color = Color.DIM_GRAY
@export var BAR_COLOUR:Color = Color(Color.GHOST_WHITE, 0.6)
@export var OVER_COLOUR:Color = Color.DARK_RED

@export var G_SUB:int = 50 #Graph Subdivision

var points_arr:PackedFloat32Array
var default_font:Font
var default_font_size:int

func _ready() -> void:
	default_font = ThemeDB.fallback_font
	default_font_size = ThemeDB.fallback_font_size
	
	points_arr.resize(G_SUB)
	points_arr.fill(0)

func process_redraw(new_point:float)->void:
	
	add_point(new_point)
	#print(points_arr)
	
	queue_redraw()

func add_point(point:float)->void:
	points_arr.append(point)
	if points_arr.size() > G_SUB:
		points_arr.remove_at(0)

func clear_points()->void:
	points_arr.fill(0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, self.size), Color(BG_COLOUR), true)
	
	var x_size_div:float = self.size.x / G_SUB
	
	var c:int = 0
	for i:float in points_arr:
		var i_colour:Color = BAR_COLOUR
		var i_height:float = -self.size.y*clamp(i, 0.0, 1.0)
		if(i >= 1.0):
			i_colour = OVER_COLOUR
		
		draw_rect(Rect2(Vector2(x_size_div*c, self.size.y), Vector2(x_size_div, i_height)), i_colour, true)
		c += 1
	
	
	draw_string(default_font, Vector2(5, 20), TITLE+" - "+str(snapped( (points_arr[-1]*100), 0.1) )+TITLE_PREFIX, HORIZONTAL_ALIGNMENT_LEFT, -1, default_font_size)
