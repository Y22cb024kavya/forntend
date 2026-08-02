import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/calendar_actions.dart';
import 'package:myapp/services/backend_service.dart';

// Home "Prep & Plan" CTA contract: invoke the planner shell with the
// structured Tomorrow Prep calendar action; adaptive recommendation is
// non-routing context_hint.
void main() {
  const mealHint =
      "I haven't met my calorie goal today. Suggest healthy meals I can prepare now.";
  const workoutHint = 'Time for your workout — plan a session that fits today.';
  const weeklyHint = 'Help me plan my week: schedule, meals, and daily outfits.';

  group('Prep & Plan CTA → planner Tomorrow Prep', () {
    test('meal adaptive content → module=planner', () {
      expect(prepPlanCardRequest(mealHint).module, 'planner');
    });

    test('workout adaptive content → module=planner', () {
      expect(prepPlanCardRequest(workoutHint).module, 'planner');
    });

    test('weekly adaptive content → module=planner', () {
      expect(prepPlanCardRequest(weeklyHint).module, 'planner');
    });

    test('adaptive text is not sent as the routing message', () {
      for (final hint in const [mealHint, workoutHint, weeklyHint]) {
        final req = prepPlanCardRequest(
          hint,
          now: DateTime(2026, 8, 2, 23, 59),
        );
        expect(req.message, 'Prep for tomorrow');
        expect(req.message, isNot(equals(hint)));
        // Diet/fitness keywords from the hint must not leak into the routing
        // message or change the structured Calendar action.
        expect(req.message.toLowerCase().contains('calorie'), isFalse);
        expect(
          calendarPhraseAction(req.message),
          CalendarQuickAction.prepTomorrow,
        );
        expect(req.context['calendar_action'], 'calendar_prep_tomorrow');
        expect(req.context['requested_action'], 'calendar_prep_tomorrow');
        expect(req.context['requested_plan_type'], 'tomorrow_prep');
        expect(req.context['target_date'], '2026-08-03');
        expect(req.context['source'], 'home_prep_plan_card');
        expect(req.context['surface'], 'home_prepare');
        expect(req.context.containsKey('style_this'), isFalse);
        expect(req.context.containsKey('build_outfit'), isFalse);
        expect(req.context.containsKey('anchor'), isFalse);
      }
    });

    test('context_hint is preserved', () {
      expect(prepPlanCardRequest(mealHint).context['context_hint'], mealHint);
    });

    test('routing message resolves to the planner module domain', () {
      final req = prepPlanCardRequest(mealHint);
      expect(canonicalModuleChatDomain(req.module), 'planner');
    });

    test('local time determines the Tomorrow Prep date', () {
      final req = prepPlanCardRequest(
        mealHint,
        now: DateTime(2026, 12, 31, 23, 59),
      );
      expect(req.context['target_date'], '2027-01-01');
    });
  });

  group('typed Calendar phrases still resolve (unchanged)', () {
    test('"prep tomorrow" → Tomorrow Prep', () {
      expect(calendarPhraseAction('prep tomorrow'),
          CalendarQuickAction.prepTomorrow);
    });

    test('"plan my day" → Day Plan', () {
      expect(calendarPhraseAction('plan my day'), CalendarQuickAction.planDay);
    });
  });
}
