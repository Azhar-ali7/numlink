/// Golf-style score verdicts, shared by the win sheets and stats.
enum ScoreLabel { eagle, birdie, par, bogey, doubleBogey, over }

extension ScoreLabelText on ScoreLabel {
  String text(int over) => switch (this) {
        ScoreLabel.eagle => 'Eagle',
        ScoreLabel.birdie => 'Birdie',
        ScoreLabel.par => 'Par',
        ScoreLabel.bogey => 'Bogey',
        ScoreLabel.doubleBogey => 'Double bogey',
        ScoreLabel.over => '+$over',
      };
}
