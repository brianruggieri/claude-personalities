TOTAL_FRAMES = 10
MAX_PINS = 10
MIN_PINS = 0
BONUS_ROLLS_STRIKE = 2
BONUS_ROLLS_SPARE = 1


class BowlingGame:
    def __init__(self):
        self.rolls = []
        self.current_frame = 0
        self.current_frame_rolls = 0
        self.game_over = False

    def roll(self, pins):
        _validate_not_game_over(self)
        _validate_pin_count(pins)
        _validate_frame_pins(self, pins)
        self.rolls.append(pins)
        _advance_frame(self)

    def score(self):
        _validate_game_complete(self)
        return _compute_score(self.rolls)


def _validate_not_game_over(game):
    if game.game_over:
        raise Exception("Game is already over")


def _validate_pin_count(pins):
    if pins < MIN_PINS or pins > MAX_PINS:
        raise Exception("Invalid pin count")


def _validate_frame_pins(game, pins):
    if game.current_frame < TOTAL_FRAMES - 1:
        _validate_normal_frame(game, pins)
    else:
        _validate_tenth_frame(game, pins)


def _validate_normal_frame(game, pins):
    if game.current_frame_rolls == 1:
        first = game.rolls[-1]
        if first + pins > MAX_PINS:
            raise Exception("Pin count exceeds pins on lane")


def _validate_tenth_frame(game, pins):
    if game.current_frame_rolls == 1:
        _validate_tenth_second_roll(game, pins)
    elif game.current_frame_rolls == BONUS_ROLLS_STRIKE:
        _validate_tenth_third_roll(game, pins)


def _validate_tenth_second_roll(game, pins):
    first = game.rolls[-1]
    if first != MAX_PINS and first + pins > MAX_PINS:
        raise Exception("Pin count exceeds pins on lane")


def _validate_tenth_third_roll(game, pins):
    first = game.rolls[-BONUS_ROLLS_STRIKE]
    second = game.rolls[-1]
    if second == MAX_PINS:
        return
    if first == MAX_PINS and second + pins > MAX_PINS:
        raise Exception("Pin count exceeds pins on lane")


def _advance_frame(game):
    if game.current_frame < TOTAL_FRAMES - 1:
        _advance_normal_frame(game)
    else:
        _advance_tenth_frame(game)


def _advance_normal_frame(game):
    pins = game.rolls[-1]
    if pins == MAX_PINS or game.current_frame_rolls == 1:
        game.current_frame += 1
        game.current_frame_rolls = 0
    else:
        game.current_frame_rolls = 1


def _advance_tenth_frame(game):
    game.current_frame_rolls += 1
    if _is_tenth_frame_done(game):
        game.game_over = True


def _is_tenth_frame_done(game):
    rolls = game.current_frame_rolls
    if rolls < BONUS_ROLLS_STRIKE:
        return False
    if rolls == BONUS_ROLLS_STRIKE:
        return _tenth_frame_no_bonus(game)
    return True


def _tenth_frame_no_bonus(game):
    first = game.rolls[-BONUS_ROLLS_STRIKE]
    second = game.rolls[-1]
    return first != MAX_PINS and first + second < MAX_PINS


def _validate_game_complete(game):
    if not game.game_over:
        raise Exception("Game is not complete")


def _compute_score(rolls):
    total = 0
    roll_index = 0
    for _ in range(TOTAL_FRAMES):
        if rolls[roll_index] == MAX_PINS:
            total += _strike_score(rolls, roll_index)
            roll_index += 1
        elif _is_spare(rolls, roll_index):
            total += _spare_score(rolls, roll_index)
            roll_index += BONUS_ROLLS_STRIKE
        else:
            total += _normal_score(rolls, roll_index)
            roll_index += BONUS_ROLLS_STRIKE
    return total


def _is_spare(rolls, index):
    return rolls[index] + rolls[index + 1] == MAX_PINS


def _strike_score(rolls, index):
    return MAX_PINS + rolls[index + 1] + rolls[index + BONUS_ROLLS_STRIKE]


def _spare_score(rolls, index):
    return MAX_PINS + rolls[index + BONUS_ROLLS_STRIKE]


def _normal_score(rolls, index):
    return rolls[index] + rolls[index + 1]
