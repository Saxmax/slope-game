class_name Player extends Node2D

var sprite: Sprite2D;

var start_position := Vector2(500, -50); #220
var play_position := Vector2(358, 335);
var tween_middle_x := 210; #510;
var tween_duration := 2.0;

var SKI_ROTATION := 0

var isDown := false
var isChanged := false

var movement_speed := 350.0;

var width := 0.0;
var height := 0.0;

func _ready() -> void:
	Game.instance.game_ready.connect(game_ready);
	sprite = $PlayerTexture;

	var size = sprite.texture.get_size();
	var factor = scale.x;
	width = size.x * factor;
	height = size.y * factor;

	SKI_ROTATION = self.get_meta("SKI_ROTATION")
	update_player()

func game_ready() -> void:
	self.position = start_position;

	var tween = create_tween();
	tween.set_ease(Tween.EASE_OUT);
	tween.tween_property(self, "position", play_position, tween_duration);
	await tween.finished;
	Game.instance.player_ready.emit();

func _input(event: InputEvent) -> void:
	if not Game.isPlaying: return;

	if event is not InputEventScreenTouch:
		return
	var current = isDown
	isDown = event.pressed

	if isDown != current:
		isChanged = true
		update_player()

func _process(delta: float) -> void:
	if not Game.isPlaying: return;

	move_player(delta, 1 if isDown else -1);
	check_bounds();

func move_player(delta: float, direction_multiplier: int) -> void:
	var speed = movement_speed * direction_multiplier;
	var dx = speed * delta;
	position.x += dx;

func check_bounds() -> void:
	var x = position.x;
	var isOutsideLeft = x < 0 - width;
	var isOutsideRight = x > Game.size.x + width;

	if isOutsideLeft or isOutsideRight:
		Game.instance.endGame();

func update_player() -> void:
	isChanged = false
	sprite.flip_h = isDown
	sprite.rotation_degrees = get_player_rotation()

func get_player_rotation() -> int:
	return SKI_ROTATION if isDown else -SKI_ROTATION
