class_name TreeObject extends Node2D

var speed := 500.0;
var sprite: Sprite2D;

func _ready() -> void:
	sprite = $TreeTexture
	sprite.flip_h = randi_range(0, 1) == 1;

func slalom(area: Area2D) -> void:
	shake(false);

func crash(area: Area2D) -> void:
	shake(false);

func shake(isCrash := false) -> void:
	print("crashed!" if isCrash else "slalomed!")
	rotation_degrees = 0;
	var shake_duration = 0.5 if isCrash else 0.1;
	var tween = create_tween();

	if isCrash:
		tween.set_trans(Tween.TRANS_QUAD);
		tween.set_ease(Tween.EASE_IN_OUT);

	tween.tween_property(self, "rotation_degrees", 6, shake_duration);
	tween.tween_property(self, "rotation_degrees", 0, shake_duration);

	if isCrash:
		tween.set_ease(Tween.EASE_IN);
		tween.tween_property(self, "rotation", 1.3, 1.0).set_delay(0.5);
