extends Node2D

@export var texture: Texture2D
@export var scroll_speed: float = 40.0
@export var direction: Vector2 = Vector2(0, 1)
@export var scale_to_viewport: bool = true
@export var sprite_a_path: NodePath = ^"SpriteA"
@export var sprite_b_path: NodePath = ^"SpriteB"

var _sprite_a: Sprite2D
var _sprite_b: Sprite2D
var _segment_height: float = 0.0

func _ready() -> void:
	_sprite_a = get_node_or_null(sprite_a_path)
	_sprite_b = get_node_or_null(sprite_b_path)
	if _sprite_a == null or _sprite_b == null:
		push_error("ScrollingBackground requires SpriteA and SpriteB children")
		set_process(false)
		return

	if texture == null:
		texture = _sprite_a.texture
	if texture == null:
		push_error("ScrollingBackground requires a texture")
		set_process(false)
		return

	_sprite_a.texture = texture
	_sprite_b.texture = texture
	_sprite_a.centered = false
	_sprite_b.centered = false

	var tex_size := texture.get_size()
	var scale_factor := Vector2.ONE
	if scale_to_viewport and tex_size.x > 0.0 and tex_size.y > 0.0:
		var viewport_size := get_viewport_rect().size
		scale_factor = Vector2(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	_sprite_a.scale = scale_factor
	_sprite_b.scale = scale_factor
	_segment_height = tex_size.y * scale_factor.y

	_sprite_a.position = Vector2.ZERO
	_sprite_b.position = Vector2(0, -_segment_height)

func _process(delta: float) -> void:
	if _segment_height <= 0.0:
		return

	var offset := direction.normalized() * scroll_speed * delta
	_sprite_a.position += offset
	_sprite_b.position += offset

	if direction.y >= 0.0:
		if _sprite_a.position.y >= _segment_height:
			_sprite_a.position.y -= _segment_height * 2.0
		if _sprite_b.position.y >= _segment_height:
			_sprite_b.position.y -= _segment_height * 2.0
	else:
		if _sprite_a.position.y <= -_segment_height:
			_sprite_a.position.y += _segment_height * 2.0
		if _sprite_b.position.y <= -_segment_height:
			_sprite_b.position.y += _segment_height * 2.0
