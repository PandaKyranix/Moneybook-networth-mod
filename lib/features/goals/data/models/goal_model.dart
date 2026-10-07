import '../../domain/entities/goal.dart';

class GoalModel extends Goal {
  const GoalModel({
    required super.id,
    required super.name,
    required super.goalAmount,
    required super.currency,
    required super.startDate,
    required super.endDate,
    super.state,
    super.completedDate,
    super.accountName,
    super.savedAmount,
  });

  /// Liest ein Ziel aus einer Zeile von `goals LEFT JOIN accounts` (Spalten accountName / accountAmount).
  factory GoalModel.fromDbMap(Map goal) {
    final Object? completedDate = goal['completedDate'];
    final GoalStatus state = GoalStatus.fromString(goal['state'] as String?);
    final num? finalAmount = goal['finalAmount'] as num?;
    return GoalModel(
      id: goal['id'],
      name: goal['name'],
      goalAmount: (goal['goalAmount'] as num).toDouble(),
      currency: goal['currency'],
      startDate: DateTime.parse(goal['startDate']),
      endDate: DateTime.parse(goal['endDate']),
      state: state,
      completedDate: completedDate is String && completedDate.isNotEmpty ? DateTime.parse(completedDate) : null,
      accountName: (goal['accountName'] as String?) ?? goal['name'],
      // Aktive Ziele: aktueller Kontostand. Abgeschlossene Ziele: Betrag beim Abschluss (Konto ist dann leer).
      savedAmount: state != GoalStatus.active && finalAmount != null
          ? finalAmount.toDouble()
          : ((goal['accountAmount'] as num?) ?? 0.0).toDouble(),
    );
  }
}
