import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import '../../../goals/domain/usecases/create.dart';
import '../../../goals/domain/usecases/delete.dart';
import '../../../goals/domain/usecases/load.dart';
import '../../../goals/domain/usecases/loadAll.dart';
import '../../../goals/domain/usecases/update.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_calculator.dart';

part 'goal_event.dart';
part 'goal_state.dart';

const String CREATE_GOAL_FAILURE = 'Ziel konnte nicht erstellt werden.';
const String UPDATE_GOAL_FAILURE = 'Ziel konnte nicht bearbeitet werden.';
const String DELETE_GOAL_FAILURE = 'Ziel konnte nicht gelöscht werden.';
const String LOAD_GOAL_FAILURE = 'Ziel konnte nicht geladen werden.';
const String LOAD_ALL_GOALS_FAILURE = 'Ziele konnten nicht geladen werden.';
const String ADD_MONEY_GOAL_FAILURE = 'Geld konnte nicht zum Ziel hinzugefügt werden.';
const String CLOSE_GOAL_FAILURE = 'Ziel konnte nicht abgeschlossen werden.';

class GoalBloc extends Bloc<GoalEvent, GoalState> {
  final Create createUseCase;
  final Update updateUseCase;
  final Delete deleteUseCase;
  final Load loadUseCase;
  final LoadAll loadAllUseCase;

  GoalBloc(
    this.createUseCase,
    this.updateUseCase,
    this.deleteUseCase,
    this.loadUseCase,
    this.loadAllUseCase,
  ) : super(GoalInitial()) {
    on<GoalEvent>((event, emit) async {
      final GoalRepository goalRepository = createUseCase.goalRepository;
      if (event is! LoadAllGoals) {
        emit(GoalSaving());
      }
      if (event is CreateGoal) {
        final createGoalEither = await goalRepository.create(event.goal);
        createGoalEither.fold((failure) {
          emit(failure is GoalNameTakenFailure ? GoalNameTaken(name: event.goal.name) : const Error(message: CREATE_GOAL_FAILURE));
        }, (_) {
          emit(Finished());
        });
      } else if (event is UpdateGoal) {
        final updateGoalEither = await goalRepository.update(event.goal);
        updateGoalEither.fold((failure) {
          emit(failure is GoalNameTakenFailure ? GoalNameTaken(name: event.goal.name) : const Error(message: UPDATE_GOAL_FAILURE));
        }, (_) {
          emit(Finished());
        });
      } else if (event is LoadAllGoals) {
        emit(GoalLoading());
        final loadAllGoalsEither = await goalRepository.loadAll();
        loadAllGoalsEither.fold((failure) {
          emit(const GoalLoadFailure(message: LOAD_ALL_GOALS_FAILURE));
        }, (goals) {
          emit(AllGoalsLoadedSuccessful(goals: goals));
        });
      } else if (event is AddMoneyToGoal) {
        final addMoneyEither = await goalRepository.addMoney(
          goal: event.goal,
          fromAccount: event.fromAccount,
          amount: event.amount,
          date: DateTime.now(),
        );
        addMoneyEither.fold((failure) {
          emit(const Error(message: ADD_MONEY_GOAL_FAILURE));
        }, (_) {
          emit(Finished());
        });
      } else if (event is CloseGoal) {
        final closeGoalEither = await goalRepository.close(
          goal: event.goal,
          action: event.action,
          targetAccountName: event.targetAccountName,
          categorie: event.categorie,
          date: DateTime.now(),
        );
        closeGoalEither.fold((failure) {
          emit(Error(message: event.action == GoalCloseAction.delete ? DELETE_GOAL_FAILURE : CLOSE_GOAL_FAILURE));
        }, (_) {
          emit(Finished());
        });
      }
    });
  }
}
