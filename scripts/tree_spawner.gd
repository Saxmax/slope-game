class_name TreeSpawner extends Node

var tree_prefab := preload("res://scenes/tree.tscn");
var tree_width := 108;

var trees: Array[TreeObject] = [];
var trees_resetted := 0;

func game_ready() -> void:
	create(10);

func create(count: int):
	for i in count:
		var x = randi_range(0, Game.size.x);
		var y = randi_range(0, Game.size.y);
		var position := Vector2(x, y + Game.size.y + 200);

		var tree = tree_prefab.instantiate() as TreeObject;
		tree.position = position;

		Game.instance.rendering_layer.add_child(tree);
		trees.push_back(tree);

func _process(delta: float) -> void:
	if not Game.isPlaying: return;

	for tree in trees:
		tree.position.y -= tree.speed * delta;

		if tree.position.y < -20:
			reset(tree);

func reset(tree: TreeObject):
	print("Resetting")
	var position := Vector2i(randi_range(0, Game.size.x), randi_range(Game.size.y + 180, Game.size.y + 280));
	tree.position = position;

	trees_resetted += 1;
	if trees_resetted == trees.size():
		trees_resetted = 0;
		create(1);
