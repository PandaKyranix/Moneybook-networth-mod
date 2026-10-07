part of 'goal_bloc.dart';

@immutable
sealed class GoalEvent extends Equatable {
  const GoalEvent();
}

class CreateGoal extends GoalEvent {
  final Goal goal;

  const CreateGoal(this.goal);

  @override
  List<Object?> get props => [goal];
}

class UpdateGoal extends GoalEvent {
  final Goal goal;

  const UpdateGoal(this.goal);

  @override
  List<Object?> get props => [goal];
}

class LoadAllGoals extends GoalEvent {
  const LoadAllGoals();

  @override
  List<Object?> get props => [];
}

/// Übertrag von einem Konto auf das Ziel-Konto.
class AddMoneyToGoal extends GoalEvent {
  final Goal goal;
  final String fromAccount;
  final double amount;

  const AddMoneyToGoal({required this.goal, required this.fromAccount, required this.amount});

  @override
  List<Object?> get props => [goal, fromAccount, amount];
}

/// Ziel abschließen ("Gekauft" / "Erreicht") oder löschen.
class CloseGoal extends GoalEvent {
  final Goal goal;
  final GoalCloseAction action;
  final String? targetAccountName;
  final String categorie;

  const CloseGoal({required this.goal, required this.action, this.targetAccountName, this.categorie = ''});

  @override
  List<Object?> get props => [goal, action, targetAccountName, categorie];
}
