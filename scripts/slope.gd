class_name Slope extends Node2D

# Preloaded assets
var tree_prefab := preload("res://scenes/tree.tscn");

# References
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
var TREE_TREE_TEXTURE = "TreeTexture";
var TREE_SNOW_TEXTURE = "SnowTexture";
var TREE_PARTICLES = "Particles";
var TREE_SLALOM_AREA = "SlalomArea";
var TREE_TRUNK_AREA = "TrunkArea";
var TREE_DATA_TREE = "tree";
var TREE_DATA_TEXTURE = "texture";
var TREE_DATA_SNOW = "snow";
var TREE_DATA_EMITTER = "emitter";
var TREE_DATA_TWEEN = "tween";

# Vectors
var game_size: Vector2i;
var player_start_position := Vector2(500, -50); #220
var player_play_position := Vector2(358, 335);

# Booleans
var isPlaying := false;
var isDown := false;
var isCrashed := false;

# Numbers
var player_middle_x := 210; #510;
var player_tween_duration := 2.0;
var player_rotation := 20;
var player_speed := 350.0;
var player_width := 0.0;
var player_height := 0.0;
var tree_speed := 500.0;
var tree_width := 108;
var tree_shake_angle := 6;
var tree_shake_duration_short = 0.1;
var tree_shake_duration_long = 0.5;
var tree_fell_rotation := 1.3;
var tree_fell_duration := 1.0;
var tree_fell_delay := 0.5;
var tree_reset_count := 0;
var initial_tree_count := 10;
var additional_tree_count := 1;

# Other
var current_trees: Array[Dictionary] = [];
enum PlayButtonState { Hidden, Inactive, Active };

# Primary callables
func _ready() -> void:
	play_button = $UserInterface/PlayButton
	tree_spawner = $TreeSpawner
	rendering_layer = $RenderingLayer;
	player = $RenderingLayer/Player;
	player_sprite = $RenderingLayer/Player/PlayerTexture;
	player_area = $RenderingLayer/Player/CollisionArea;

	game_size = get_viewport().get_visible_rect().size;

	var player_size = player_sprite.texture.get_size();
	var factor = scale.x;
	player_width = player_size.x * factor;
	player_height = player_size.y * factor;

	play_button.pressed.connect(on_play_button_pressed);
	player_area.area_entered.connect(on_player_area_entered);

	setup_world();

func _input(event: InputEvent) -> void:
	if event is not InputEventScreenTouch or not isPlaying: return;

	var prev = isDown;
	isDown = event.pressed;
	if isDown != prev:
		set_player_direction(isDown);

func _process(delta: float) -> void:
	if not isPlaying: return;

	update_trees(delta);
	update_player(delta);

# Game flow callables
func setup_world() -> void:
	set_playbutton_state(PlayButtonState.Inactive);

	create_trees(initial_tree_count);
	reset_player();
	animate_player_ready();

	# Wait for the animation to finish, then enable the PlayButton.
	await get_tree().create_timer(player_tween_duration).timeout;
	set_playbutton_state(PlayButtonState.Active);

func round_start() -> void:
	if isPlaying: return;
	isPlaying = true;

func round_end() -> void:
	if not isPlaying: return;
	isPlaying = false;
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
		var x = randi_range(0, game_size.x);
		var y = randi_range(0, game_size.y);
		var position := Vector2(x, y + game_size.y + 200);
		tree.position = position;
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

func reset_tree(tree_data: Dictionary) -> void:
	var tree = tree_data["tree"];

	var tween = tree_data["tween"];
	if tween and tween.is_running(): tween.kill();

	var position := Vector2i(randi_range(0, game_size.x), randi_range(game_size.y + 280, game_size.y + 380));
	tree.position = position;
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
		tree.position.y -= tree_speed * delta;

		if tree.position.y < -50:
			reset_tree(tree_data);

func shake_tree(tree_data: Dictionary, isCrash: bool) -> void:
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
		tween.tween_property(tree, "rotation", fell_rotation, tree_fell_duration).set_delay(tree_fell_delay);
		await tween.finished;
		round_end();

func clear_trees() -> void:
	for tree_data in current_trees:
		var tree = tree_data["tree"];
		tree.queue_free;

	current_trees = [];

# Player callables
func update_player(delta: float) -> void:
	if isCrashed: return;

	move_player(delta, 1 if isDown else -1);
	check_player_bounds();

func set_player_direction(isDown: bool) -> void:
	var rotation = player_rotation if isDown else -player_rotation;
	player_sprite.rotation_degrees = rotation;
	player_sprite.flip_h = isDown;

func move_player(delta: float, direction_multiplier: int) -> void:
	var speed = player_speed * direction_multiplier;
	var dx = speed * delta;
	player.position.x += dx;

func check_player_bounds() -> void:
	var x = player.position.x;
	var isOutsideLeft = x < 0 - player_width;
	var isOutsideRight = x > game_size.x + player_width;

	if isOutsideLeft or isOutsideRight:
		# TODO
		round_end();

func reset_player() -> void:
	player.position = player_start_position;
	player_sprite.rotation_degrees = -player_rotation;
	isCrashed = false;

func animate_player_ready() -> void:
	var tween = create_tween();
	tween.set_ease(Tween.EASE_OUT);
	tween.tween_property(player, "position", player_play_position, player_tween_duration);

func animate_player_bounds() -> void:
	pass;

func animate_player_crash() -> void:
	pass;

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
