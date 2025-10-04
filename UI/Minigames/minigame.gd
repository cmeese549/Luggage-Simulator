extends Node2D

class_name Minigame

# Game state
enum GameState { PLAYING, WON }
var current_state: GameState = GameState.PLAYING

# Signals
signal _game_won

#OVERWRITE
func start_game():
	pass
