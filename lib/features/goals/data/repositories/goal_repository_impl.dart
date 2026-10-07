import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_calculator.dart';
import '../datasources/goal_local_data_source.dart';

class GoalRepositoryImpl implements GoalRepository {
  final GoalLocalDataSource goalLocalDataSource;

  GoalRepositoryImpl({
    required this.goalLocalDataSource,
  });

  /// Führt eine Datenbank-Operation aus und wandelt Fehler in Failures um.
  Future<Either<Failure, T>> _run<T>(Future<T> Function() operation) async {
    try {
      return Right(await operation());
    } on GoalNameTakenException {
      return Left(GoalNameTakenFailure());
    } catch (error) {
      return Left(GoalOperationFailure(error.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> create(Goal goal) => _run(() => goalLocalDataSource.create(goal));

  @override
  Future<Either<Failure, void>> update(Goal goal) => _run(() => goalLocalDataSource.update(goal));

  @override
  Future<Either<Failure, void>> delete(int id) => _run(() => goalLocalDataSource.delete(id));

  @override
  Future<Either<Failure, Goal>> load(int id) => _run(() => goalLocalDataSource.load(id));

  @override
  Future<Either<Failure, List<Goal>>> loadAll() => _run(() => goalLocalDataSource.loadAll());

  @override
  Future<Either<Failure, List<Booking>>> loadGoalBookings(String accountName) => _run(() => goalLocalDataSource.loadGoalBookings(accountName));

  @override
  Future<Either<Failure, bool>> isNameTaken(String name, {int exceptGoalId = 0}) =>
      _run(() => goalLocalDataSource.isNameTaken(name, exceptGoalId: exceptGoalId));

  @override
  Future<Either<Failure, int>> countPlannedBookings(String accountName) => _run(() => goalLocalDataSource.countPlannedBookings(accountName));

  @override
  Future<Either<Failure, void>> addMoney({required Goal goal, required String fromAccount, required double amount, required DateTime date}) =>
      _run(() => goalLocalDataSource.addMoney(goal: goal, fromAccount: fromAccount, amount: amount, date: date));

  @override
  Future<Either<Failure, void>> close({
    required Goal goal,
    required GoalCloseAction action,
    String? targetAccountName,
    String categorie = '',
    required DateTime date,
  }) =>
      _run(() => goalLocalDataSource.close(goal: goal, action: action, targetAccountName: targetAccountName, categorie: categorie, date: date));
}
