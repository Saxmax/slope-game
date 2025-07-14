class_name TreeObject extends Node2D

var speed := 500.0;
var sprite: Sprite2D;

func _ready() -> void:
	sprite = $Sprite2D
	sprite.flip_h = randi_range(0, 1) == 1;
