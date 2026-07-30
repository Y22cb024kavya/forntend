/// Central Planner action → (canonical module, submitted prompt).
///
/// One source of truth so explicit Planner tiles bypass the local generic
/// "prepare" overlay and always reach /api/module-chat with a real user
/// request. `module` is the sheet moduleContext (backend-canonical after
/// [canonicalModuleChatDomain]); `prompt` is submitted as a user message,
/// not shown as a mere suggestion.
class PlannerRoute {
  final String module;
  final String prompt;
  const PlannerRoute(this.module, this.prompt);
}

/// Keyed by the existing prepare-chip ids (see `_prepareChipKeys` in home.dart).
/// Packing carries the canonical pack trigger words (pack + carry-on + trip)
/// so the backend plan_pack handler fires; the rest ride the planner module.
const Map<String, PlannerRoute> _plannerRoutes = {
  'prepare_carry_on': PlannerRoute('prepare', 'Pack for a carry-on trip'),
  'prepare_birthday': PlannerRoute('prepare', 'Plan a birthday party'),
  'prepare_camping': PlannerRoute('prepare', 'Pack and plan a camping trip'),
  'prepare_wedding': PlannerRoute('prepare', 'Plan for a wedding'),
  'prepare_workout': PlannerRoute('fitness', 'Plan a gym workout routine'),
  'prepare_meal_prep': PlannerRoute('diet', 'Plan a weekly meal prep'),
  'prepare_dev_project': PlannerRoute('prepare', 'Plan a new coding project setup'),
  'prepare_moving': PlannerRoute('prepare', 'Plan a house-move checklist'),
  'prepare_study': PlannerRoute('prepare', 'Plan an exam study schedule'),
  'prepare_gardening': PlannerRoute('prepare', 'Plan a garden planting'),
};

PlannerRoute plannerRouteFor(String actionId) =>
    _plannerRoutes[actionId.trim()] ??
    PlannerRoute('prepare', actionId.trim());
