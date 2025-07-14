class_name Game extends Node

static var instance: Game;
static var isPlaying := false;
static var size: Vector2i;

signal game_ready
signal game_start
signal game_end
signal player_ready

var player_prefab := preload("res://scenes/player.tscn");

var play_button: PlayButton;
var tree_spawner: TreeSpawner;
var rendering_layer: Node2D;

func _ready() -> void:
	instance = self;
	play_button = $UserInterface/PlayButton
	tree_spawner = $TreeSpawner
	rendering_layer = $RenderingLayer;

	size = DisplayServer.window_get_size();

	var player = player_prefab.instantiate() as Player;
	rendering_layer.add_child(player);

	game_ready.emit();

func _process(_delta: float) -> void:
	if isPlaying == false: return;

func playGame():
	if isPlaying: return;

	isPlaying = true;
	game_start.emit();

func endGame():
	if not isPlaying: return;

	play_button.reset_button();
	isPlaying = false;
	game_end.emit();
	print("GAME OVER");
