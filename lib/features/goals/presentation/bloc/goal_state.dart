part of 'goal_bloc.dart';

@immutable
sealed class GoalState extends Equatable {
  const GoalState();
}

final class GoalInitial extends GoalState {
  @override
  List<Object> get props => [];
}

final class GoalLoading extends GoalState {
  @override
  List<Object> get props => [];
}

final class AllGoalsLoadedSuccessful extends GoalState {
  final List<Goal> goals;

  const AllGoalsLoadedSuccessful({required this.goals});

  @override
  List<Object> get props => [goals];
}

/// Die Ziele konnten nicht geladen werden.
final class GoalLoadFailure extends GoalState {
  final String message;

  const GoalLoadFailure({required this.message});

  @override
  List<Object> get props => [message];
}

/// Eine Änderung wird gespeichert. Wird vor jedem Ergebnis gesendet, damit auch ein wiederholtes
/// gleiches Ergebnis (z.B. zweimal derselbe vergebene Name) erneut gemeldet wird.
final class GoalSaving extends GoalState {
  @override
  List<Object> get props => [];
}

/// Eine Änderung (Erstellen, Bearbeiten, Geld hinzufügen, Abschließen, Löschen) war erfolgreich.
final class Finished extends GoalState {
  @override
  List<Object> get props => [];
}

/// Der Name ist bereits als Konto- oder Zielname vergeben.
final class GoalNameTaken extends GoalState {
  final String name;

  const GoalNameTaken({required this.name});

  @override
  List<Object> get props => [name];
}

final class Error extends GoalState {
  final String message;

  const Error({required this.message});

  @override
  List<Object> get props => [message];
}
