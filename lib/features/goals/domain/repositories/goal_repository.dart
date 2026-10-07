import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../entities/goal.dart';
import '../services/goal_calculator.dart';

/// Der Zielname ist bereits als Konto- oder Zielname vergeben.
class GoalNameTakenFailure extends Failure {
  @override
  List<Object?> get props => [];
}

/// Eine Ziel-Operation ist fehlgeschlagen; es wurde nichts verändert (Datenbank-Transaktion).
class GoalOperationFailure extends Failure {
  final String message;

  const GoalOperationFailure(this.message);

  @override
  List<Object?> get props => [message];
}

abstract class GoalRepository {
  Future<Either<Failure, void>> create(Goal goal);
  Future<Either<Failure, void>> update(Goal goal);
  Future<Either<Failure, void>> delete(int id);
  Future<Either<Failure, Goal>> load(int id);
  Future<Either<Failure, List<Goal>>> loadAll();
  Future<Either<Failure, List<Booking>>> loadGoalBookings(String accountName);
  Future<Either<Failure, bool>> isNameTaken(String name, {int exceptGoalId = 0});
  Future<Either<Failure, int>> countPlannedBookings(String accountName);
  Future<Either<Failure, void>> addMoney({required Goal goal, required String fromAccount, required double amount, required DateTime date});
  Future<Either<Failure, void>> close({
    required Goal goal,
    required GoalCloseAction action,
    String? targetAccountName,
    String categorie = '',
    required DateTime date,
  });
}
