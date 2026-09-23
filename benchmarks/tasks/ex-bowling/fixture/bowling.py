class BowlingGame:
    def __init__(self):
        self.rolls = []
        self.current_frame = 0
        self.current_frame_rolls = 0
        self.game_over = False

    def roll(self, pins):
        if self.game_over:
            raise Exception("Cannot roll after game is over")
        if not 0 <= pins <= 10:
            raise Exception("Invalid pins")

        # Frames 0-8 (normal frames)
        if self.current_frame < 9:
            if self.current_frame_rolls == 1 and self.rolls[-1] + pins > 10:
                raise Exception("Pin count exceeds pins on the lane")
            self.rolls.append(pins)
            if pins == 10 or self.current_frame_rolls == 1:
                self.current_frame += 1
                self.current_frame_rolls = 0
            else:
                self.current_frame_rolls = 1
        else:
            # 10th frame
            if self.current_frame_rolls == 0:
                self.rolls.append(pins)
                self.current_frame_rolls = 1
            elif self.current_frame_rolls == 1:
                if self.rolls[-1] != 10 and self.rolls[-1] + pins > 10:
                    raise Exception("Pin count exceeds pins on the lane")
                self.rolls.append(pins)
                if self.rolls[-1] + self.rolls[-2] >= 10:
                    self.current_frame_rolls = 2
                else:
                    self.game_over = True
            else:
                # Third roll in 10th frame
                prev2, prev1 = self.rolls[-2], self.rolls[-1]
                if prev2 == 10 and prev1 == 10:
                    pass  # anything 0-10 is fine
                elif prev2 == 10:
                    if prev1 + pins > 10:
                        raise Exception("Pin count exceeds pins on the lane")
                # spare case: any 0-10 is fine
                self.rolls.append(pins)
                self.game_over = True

    def score(self):
        if not self.game_over and not (self.current_frame >= 9 and self.current_frame_rolls == 0 and len(self.rolls) >= 20):
            # Check if game is complete
            if not self.game_over:
                raise Exception("Score cannot be taken until the end of the game")

        total, i = 0, 0
        for frame in range(10):
            if i >= len(self.rolls):
                raise Exception("Score cannot be taken until the end of the game")
            if self.rolls[i] == 10:  # strike
                if frame < 9:
                    total += 10 + self.rolls[i+1] + self.rolls[i+2]
                    i += 1
                else:
                    total += self.rolls[i] + self.rolls[i+1] + self.rolls[i+2]
                    i += 3
            elif self.rolls[i] + self.rolls[i+1] == 10:  # spare
                if frame < 9:
                    total += 10 + self.rolls[i+2]
                    i += 2
                else:
                    total += self.rolls[i] + self.rolls[i+1] + self.rolls[i+2]
                    i += 3
            else:
                total += self.rolls[i] + self.rolls[i+1]
                i += 2
        return total
