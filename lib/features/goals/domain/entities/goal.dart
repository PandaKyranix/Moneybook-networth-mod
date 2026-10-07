import 'package:equatable/equatable.dart';

/// Status eines Sparziels. Gelöschte Ziele bleiben als Datensatz erhalten (archiviert),
/// damit ihre früheren Buchungen weiterhin eindeutig zugeordnet werden können.
enum GoalStatus {
  active,
  completed,
  deleted;

  static GoalStatus fromString(String? state) => switch (state) {
        'completed' => GoalStatus.completed,
        'deleted' => GoalStatus.deleted,
        _ => GoalStatus.active,
      };
}

/// Sparziel. Das gesparte Geld liegt auf einem eigenen, versteckten Ziel-Konto ([accountName]),
/// das nicht zum Vermögen zählt. [savedAmount] ist immer der aktuelle Kontostand dieses Kontos.
class Goal extends Equatable {
  final int id;
  final String name;
  final double goalAmount;
  final String currency;
  final DateTime startDate;

  /// Deadline des Ziels.
  final DateTime endDate;
  final GoalStatus state;
  final DateTime? completedDate;

  /// Name des Ziel-Kontos (wie der Name des Ziels). Buchungen verweisen über diesen Namen auf das Konto.
  final String accountName;

  /// Aktueller Kontostand des Ziel-Kontos.
  final double savedAmount;

  const Goal({
    required this.id,
    required this.name,
    required this.goalAmount,
    required this.currency,
    required this.startDate,
    required this.endDate,
    this.state = GoalStatus.active,
    this.completedDate,
    this.accountName = '',
    this.savedAmount = 0.0,
  });

  bool get isActive => state == GoalStatus.active;

  Goal copyWith({
    int? id,
    String? name,
    double? goalAmount,
    String? currency,
    DateTime? startDate,
    DateTime? endDate,
    GoalStatus? state,
    DateTime? completedDate,
    String? accountName,
    double? savedAmount,
  }) {
    return Goal(
      id: id ?? this.id,
      name: name ?? this.name,
      goalAmount: goalAmount ?? this.goalAmount,
      currency: currency ?? this.currency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      state: state ?? this.state,
      completedDate: completedDate ?? this.completedDate,
      accountName: accountName ?? this.accountName,
      savedAmount: savedAmount ?? this.savedAmount,
    );
  }

  @override
  List<Object?> get props => [id, name, goalAmount, currency, startDate, endDate, state, completedDate, accountName, savedAmount];
}
