class_name Slope extends Node2D

# Preloaded assets
const tree_prefab := preload("res://scenes/tree.tscn");

# References
var background: TextureRect;
var play_button: Button;
var tree_spawner: Node2D;
var rendering_layer: Node2D;
var player: Node2D;
var player_sprite: Sprite2D;
var player_area: Area2D;
var tree_sprite: Sprite2D;
var tree_snow: Sprite2D;
var tree_emitter: GPUParticles2D;

# Constants
const TREE_TREE_TEXTURE := "TreeTexture";
const TREE_SNOW_TEXTURE := "SnowTexture";
const TREE_PARTICLES := "Particles";
const TREE_SLALOM_AREA := "SlalomArea";
const TREE_TRUNK_AREA := "TrunkArea";
const TREE_DATA_TREE := "tree";
const TREE_DATA_TEXTURE := "texture";
const TREE_DATA_SNOW := "snow";
const TREE_DATA_EMITTER := "emitter";
const TREE_DATA_TWEEN := "tween";
const BACKGROUND_SCROLL_PARAM = "scrollY";

# Vectors
const player_start_position := Vector2(500, -50);
const player_play_position := Vector2(358, 335);
var game_size: Vector2i;

# Booleans
var is_game_started := false;
var is_input_down := false;
var is_player_crashed := false;
var has_pressed_once := false;
var animate_trees_round_start := false;
var has_calculated_tree_size := false;

# Numbers
const player_middle_x := 210;
const player_tween_duration := 2.0;
const player_rotation := 20;
const player_speed := 350.0;
const player_bounds_rotation := PI * 6.5;
const player_bounds_distance := 250;
const player_bounds_duration := 1.5;
const player_bounds_end_delay := 2.0;
const tree_speed := 500.0;
const tree_animation_speed := 300.0;
const tree_shake_angle := 6;
const tree_shake_duration_short = 0.1;
const tree_shake_duration_long = 0.5;
const tree_fell_rotation := 1.3;
const tree_fell_duration := 1.0;
const tree_fell_delay := 0.5;
const initial_tree_count := 10;
const additional_tree_count := 1;
var player_width := 0.0;
var player_height := 0.0;
var tree_width := 0.0;
var tree_height := 0.0;
var tree_reset_count := 0;
var background_texture_height := 0;
var background_scroll := 0.0;

# Other
var current_trees: Array[Dictionary] = [];
enum PlayButtonState { Hidden, Inactive, Active };

# Primary callables
func _ready() -> void:
	background = $Background;
	play_button = $UserInterface/PlayButton
	tree_spawner = $TreeSpawner
	rendering_layer = $RenderingLayer;
	player = $RenderingLayer/Player;
	player_sprite = $RenderingLayer/Player/PlayerTexture;
	player_area = $RenderingLayer/Player/CollisionArea;

	game_size = get_viewport().get_visible_rect().size;
	background_texture_height = background.texture.get_height();

	var player_size = player_sprite.texture.get_size();
	var player_scale = player_sprite.scale.x;
	player_width = player_size.x * player_scale;
	player_height = player_size.y * player_scale;

	play_button.pressed.connect(on_play_button_pressed);
	player_area.area_entered.connect(on_player_area_entered);

	setup_world();

func _input(event: InputEvent) -> void:
	if event is not InputEventScreenTouch or not is_game_started or is_player_crashed: return;

	if not has_pressed_once:
		has_pressed_once = not event.pressed;
		return;

	var prev = is_input_down;
	is_input_down = event.pressed;
	if is_input_down != prev:
		set_player_direction(is_input_down);

func _process(delta: float) -> void:

	var should_process = is_game_started and not is_player_crashed and has_pressed_once;
	var should_process_trees = animate_trees_round_start or should_process;

	if should_process_trees:
		update_trees(delta);
		update_background(delta);

	if not should_process: return;
	update_player(delta);

# Game flow callables
func setup_world() -> void:
	set_playbutton_state(PlayButtonState.Inactive);

	create_trees(initial_tree_count);
	reset_player();
	animate_player_ready();

	tree_reset_count = 0;
	animate_trees_round_start = true;
	has_pressed_once = false;
	is_input_down = false;

	# Wait for the animation to finish, then enable the PlayButton.
	await get_tree().create_timer(player_tween_duration).timeout;
	animate_trees_round_start = false;
	set_playbutton_state(PlayButtonState.Active);

func round_start() -> void:
	if is_game_started: return;
	is_game_started = true;

func round_end() -> void:
	if not is_game_started: return;
	is_game_started = false;
	player_sprite.visible = false;
	clear_trees();

	# here we can fade to black, before re-positioning things, and fading back in
	await get_tree().create_timer(1).timeout;
	setup_world();

# Tree callables
func create_trees(count: int):
	for i in count:
		# Instantiate prefab
		var tree = tree_prefab.instantiate() as Node2D;

		# Get references
		var texture = tree.get_node(TREE_TREE_TEXTURE) as Sprite2D;
		var snow = tree.get_node(TREE_SNOW_TEXTURE) as Sprite2D;
		var emitter = tree.get_node(TREE_PARTICLES) as GPUParticles2D;

		# Set values
		tree.position = get_random_tree_position();
		texture.flip_h = randi_range(0, 1) == 1;

		# Finalize by adding to scene and saving in collection
		rendering_layer.add_child(tree);
		var data = {
			TREE_DATA_TREE: tree,
			TREE_DATA_TEXTURE: texture,
			TREE_DATA_SNOW: snow,
			TREE_DATA_EMITTER: emitter,
			TREE_DATA_TWEEN: tree.create_tween(),
		};
		current_trees.push_back(data);

		if not has_calculated_tree_size:
			var tree_size = player_sprite.texture.get_size();
			var tree_scale = player_sprite.scale.x;
			tree_width = tree_size.x * tree_scale;
			tree_height = tree_size.y * tree_scale;

func reset_tree(tree_data: Dictionary) -> void:
	var tree = tree_data["tree"];

	var tween = tree_data["tween"];
	if tween and tween.is_running(): tween.kill();

	tree.position = get_random_tree_position(true);
	tree.rotation = 0;

	var snow = tree_data["snow"];
	snow.visible = true;

	var emitter = tree_data["emitter"];
	emitter.restart();
	emitter.emitting = false;

	tree_reset_count += 1;
	if tree_reset_count == current_trees.size():
		tree_reset_count = 0;
		create_trees(additional_tree_count);

func update_trees(delta: float) -> void:
	for tree_data in current_trees:
		var tree = tree_data["tree"];
		var speed = tree_speed if not animate_trees_round_start else tree_animation_speed;
		tree.position.y -= speed * delta;

		if tree.position.y < -50:
			reset_tree(tree_data);

func shake_tree(tree_data: Dictionary, isCrash: bool) -> void:
	is_player_crashed = isCrash;

	# Drop the snow cover
	var snow = tree_data[TREE_DATA_SNOW];
	var emitter = tree_data[TREE_DATA_EMITTER];
	snow.visible = false;
	emitter.emitting = true;

	var tree = tree_data[TREE_DATA_TREE];
	tree.rotation = 0;

	var tween = tree_data[TREE_DATA_TWEEN];
	if tween and tween.is_running(): tween.kill();
	tween = create_tween();

	var player_left_side = player.position.x < tree.position.x;
	var shake_angle = tree_shake_angle if player_left_side else -tree_shake_angle;
	var shake_duration = tree_shake_duration_long if isCrash else tree_shake_duration_short;

	if isCrash:
		tween.set_trans(Tween.TRANS_QUAD);
		tween.set_ease(Tween.EASE_IN_OUT);

	tween.tween_property(tree, "rotation_degrees", shake_angle, shake_duration);
	tween.tween_property(tree, "rotation_degrees", 0, shake_duration);

	if isCrash:
		var fell_rotation = tree_fell_rotation if player_left_side else -tree_fell_rotation;
		tween.set_ease(Tween.EASE_IN);
		tween.tween_property(tree, "rotation", fell_rotation, tree_fell_duration);
		tween.tween_callback(round_end).set_delay(tree_fell_delay);

func clear_trees() -> void:
	for tree_data in current_trees:
		var tree = tree_data["tree"] as Node2D;
		tree.queue_free();

	current_trees.clear();

func get_random_tree_position(is_resetting := false) -> Vector2:
	var min_y = game_size.y + tree_height;
	var add_y = 300 if is_resetting else game_size.y;

	var y = randi_range(min_y, min_y + add_y);
	var x = randi_range(0, game_size.x);

	return Vector2(x, y);

# Player callables
func update_player(delta: float) -> void:
	move_player(delta, 1 if is_input_down else -1);
	check_player_bounds();

func set_player_direction(is_input_down: bool) -> void:
	var rotation = player_rotation if is_input_down else -player_rotation;
	player_sprite.rotation_degrees = rotation;
	player_sprite.flip_h = is_input_down;

func move_player(delta: float, direction_multiplier: int) -> void:
	var speed = player_speed * direction_multiplier;
	var dx = speed * delta;
	player.position.x += dx;

func check_player_bounds() -> void:
	var x = player.position.x;
	var isOutsideLeft = x < 0 - player_width;
	var isOutsideRight = x > game_size.x + player_width;

	if isOutsideLeft or isOutsideRight:
		is_player_crashed = true;
		animate_player_bounds();

func reset_player() -> void:
	player.position = player_start_position;
	set_player_direction(false);
	player_sprite.visible = true;
	is_player_crashed = false;

func animate_player_ready() -> void:
	var tween = create_tween();
	tween.set_ease(Tween.EASE_OUT);
	tween.tween_property(player, "position", player_play_position, player_tween_duration);

func animate_player_bounds() -> void:
	var is_left_side = player.position.x < game_size.x / 2.0;
	var half_width = 0;#player_width / 2.0;
	var snap_position = half_width if is_left_side else game_size.x - half_width;
	player.position.x = snap_position;

	var bounds_distance = player_bounds_distance if is_left_side else -player_bounds_distance;
	var bounds_rotation = player_bounds_rotation if is_left_side else -(player_bounds_rotation - PI);

	var tween = player_sprite.create_tween();
	tween.set_trans(Tween.TRANS_CUBIC);
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(player, "position:x", player.position.x + bounds_distance, player_bounds_duration);
	tween.parallel().tween_property(player_sprite, "rotation", player_sprite.rotation + bounds_rotation, player_bounds_duration);
	tween.tween_callback(round_end).set_delay(player_bounds_end_delay);

func animate_player_crash() -> void:
	pass;

# Background callables
func update_background(delta: float) -> void:
	var speed = tree_speed if not animate_trees_round_start else tree_animation_speed;
	background_scroll += speed * delta;
	background_scroll = fmod(background_scroll, background_texture_height);
	background.material.set_shader_parameter(BACKGROUND_SCROLL_PARAM, background_scroll / background_texture_height);

# PlayButton callables
func set_playbutton_state(state: PlayButtonState) -> void:
	var pb_disabled = true;
	var pb_visible = true;

	match state:
		PlayButtonState.Hidden:
			pb_disabled = true;
			pb_visible = false;
		PlayButtonState.Inactive:
			pb_disabled = true;
			pb_visible = true;
		PlayButtonState.Active:
			pb_disabled = false;
			pb_visible = true;

	play_button.disabled = pb_disabled;
	play_button.visible = pb_visible;

# Signal listeners
func on_play_button_pressed() -> void:
	set_playbutton_state(PlayButtonState.Hidden);
	round_start();

func on_player_area_entered(area: Area2D) -> void:
	if is_player_crashed: return;
	if area.name != TREE_SLALOM_AREA and area.name != TREE_TRUNK_AREA: return;

	var tree = area.get_parent();
	var data = null;
	for tree_data in current_trees:
		if tree_data[TREE_DATA_TREE] == tree:
			data = tree_data;
			break;

	if data == null: return;

	var isCrash = area.name == TREE_TRUNK_AREA;
	shake_tree(data, isCrash);

	if isCrash:
		animate_player_crash();
