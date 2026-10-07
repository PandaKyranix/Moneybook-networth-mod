import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../../../core/consts/common_consts.dart';
import '../../../../core/consts/route_consts.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../shared/presentation/widgets/deco/empty_list.dart';
import '../../domain/entities/goal.dart';
import '../bloc/goal_bloc.dart';
import '../widgets/buttons/add_goal_button.dart';
import '../widgets/cards/goal_card.dart';
import '../widgets/page_arguments/goal_page_arguments.dart';

/// Ziele-Tab: alle aktiven Sparziele und darunter die abgeschlossenen.
class GoalOverviewPage extends StatefulWidget {
  const GoalOverviewPage({super.key});

  @override
  State<GoalOverviewPage> createState() => _GoalOverviewPageState();
}

class _GoalOverviewPageState extends State<GoalOverviewPage> {
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    BlocProvider.of<GoalBloc>(context).add(const LoadAllGoals());
  }

  void _openGoal(BuildContext context, Goal goal) {
    Navigator.pushNamed(context, goalDetailRoute, arguments: GoalPageArguments(goal));
  }

  Widget _buildSummary(BuildContext context, List<Goal> activeGoals) {
    final double saved = activeGoals.fold(0.0, (sum, goal) => sum + goal.savedAmount);
    final double target = activeGoals.fold(0.0, (sum, goal) => sum + goal.goalAmount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 18.0, color: Colors.amberAccent),
            const SizedBox(width: 10.0),
            Expanded(
              child: Text(
                AppLocalizations.of(context).translate('in_zielen_zurückgelegt'),
                style: TextStyle(fontSize: 13.0, color: Colors.grey.shade400),
              ),
            ),
            Text(
              '${formatToMoneyAmount(saved.toString())} / ${formatToMoneyAmount(target.toString())}',
              style: const TextStyle(fontSize: 14.0, color: Colors.amberAccent),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GoalBloc, GoalState>(
      // Nur Lade-Zustände der Liste anzeigen; Speichern / Fehler werden auf den Formularseiten behandelt.
      buildWhen: (previous, current) =>
          current is GoalLoading || current is AllGoalsLoadedSuccessful || current is GoalLoadFailure || current is GoalInitial,
      builder: (context, state) {
        if (state is AllGoalsLoadedSuccessful) {
          final List<Goal> activeGoals = state.goals.where((goal) => goal.state == GoalStatus.active).toList();
          final List<Goal> completedGoals = state.goals.where((goal) => goal.state == GoalStatus.completed).toList()
            ..sort((first, second) => (second.completedDate ?? second.endDate).compareTo(first.completedDate ?? first.endDate));
          if (activeGoals.isEmpty && completedGoals.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: EmptyList(
                    text: AppLocalizations.of(context).translate('noch_keine_ziele_vorhanden'),
                    icon: Icons.flag_rounded,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 40.0),
                  child: AddGoalButton(),
                ),
              ],
            );
          }
          return AnimationLimiter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(4.0, 4.0, 4.0, 88.0),
              children: [
                if (activeGoals.isNotEmpty) _buildSummary(context, activeGoals),
                for (int i = 0; i < activeGoals.length; i++)
                  AnimationConfiguration.staggeredList(
                    position: i,
                    duration: const Duration(milliseconds: staggeredListDurationInMs),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      curve: Curves.easeOutCubic,
                      child: FadeInAnimation(
                        child: GoalCard(goal: activeGoals[i], onTap: () => _openGoal(context, activeGoals[i])),
                      ),
                    ),
                  ),
                if (activeGoals.isEmpty) const AddGoalButton(),
                if (completedGoals.isNotEmpty)
                  ListTile(
                    dense: true,
                    title: Text(
                      '${AppLocalizations.of(context).translate('abgeschlossene_ziele')} (${completedGoals.length})',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                    trailing: Icon(_showCompleted ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                    onTap: () => setState(() => _showCompleted = !_showCompleted),
                  ),
                if (_showCompleted)
                  for (final Goal goal in completedGoals) GoalCard(goal: goal, onTap: () => _openGoal(context, goal)),
              ],
            ),
          );
        } else if (state is GoalLoadFailure) {
          return Center(child: Text(AppLocalizations.of(context).translate('fehler_beim_laden_der_ziele')));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
