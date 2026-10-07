import '../../../domain/entities/goal.dart';

/// Was auf der Ziel-Aktionsseite getan wird.
enum GoalActionMode {
  addMoney,
  complete,
  delete,
}

class GoalPageArguments {
  final Goal goal;

  GoalPageArguments(this.goal);
}

class GoalActionPageArguments {
  final Goal goal;
  final GoalActionMode mode;

  GoalActionPageArguments(this.goal, this.mode);
}
