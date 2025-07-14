class_name PlayButton extends Button

signal play_button_pressed;

func setState(enabled: bool) -> void:
	disabled = not enabled;

func playButtonPressed() -> void:
	play_button_pressed.emit();
	visible = false;

func reset_button() -> void:
	visible = true;
	setState(true);
