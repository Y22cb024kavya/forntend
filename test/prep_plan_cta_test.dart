import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/models/calendar_actions.dart';
import 'package:myapp/services/backend_service.dart';

// Home "Prep & Plan" CTA contract: always invoke the planner with one stable
// routing message; adaptive recommendation is non-routing context_hint.
void main() {
  const mealHint =
      "I haven't met my calorie goal today. Suggest healthy meals I can prepare now.";
  const workoutHint = 'Time for your workout — plan a session that fits today.';
  const weeklyHint = 'Help me plan my week: schedule, meals, and daily outfits.';

  group('Prep & Plan CTA → planner', () {
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
        final req = prepPlanCardRequest(hint);
        expect(req.message, 'Help me prep and plan my day.');
        expect(req.message, isNot(equals(hint)));
        // Diet/fitness keywords from the hint must not leak into the routing
        // message, and the message must not be captured as a Calendar phrase.
        expect(req.message.toLowerCase().contains('calorie'), isFalse);
        expect(calendarPhraseAction(req.message), isNull);
        expect(req.context['requested_action'], 'plan_day');
        expect(req.context['source'], 'home_prep_plan_card');
      }
    });

    test('context_hint is preserved', () {
      expect(prepPlanCardRequest(mealHint).context['context_hint'], mealHint);
    });

    test('routing message resolves to the planner module domain', () {
      final req = prepPlanCardRequest(mealHint);
      expect(canonicalModuleChatDomain(req.module), 'planner');
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
