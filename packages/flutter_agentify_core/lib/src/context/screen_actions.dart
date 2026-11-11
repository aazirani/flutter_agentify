import '../actions/action_context.dart';
import '../actions/action_failure.dart';
import '../actions/agent_action.dart';
import '../schema/schema.dart';
import 'app_context.dart';

/// Names of the actions every Flutter Agentify app gets.
const Set<String> builtInActionNames = {
  'view_screen',
  'navigate',
  'save_memory',
  'delete_memory',
};

/// `view_screen`: a fresh, full read of the current screen.
class ViewScreenAction extends AgentAction<NoInput, Object?> {
  ViewScreenAction(this.appContext);

  final AppContext appContext;

  @override
  String get name => 'view_screen';

  @override
  String get description =>
      'Reads the current screen again: where the person is and the records '
      'it shows.';

  @override
  ObjectSchema<NoInput> get input => S.none;

  @override
  bool get readOnly => true;

  @override
  int get maxResultChars => 8000;

  @override
  Future<Object?> run(NoInput input, ActionContext context) =>
      appContext.viewScreen();

  @override
  Object? encode(Object? output) => output;
}

/// `navigate`: asks the router adapter to open a location.
class NavigateAction extends AgentAction<String, String> {
  NavigateAction(this.appContext);

  final AppContext appContext;

  @override
  String get name => 'navigate';

  @override
  String get description => 'Opens a screen of the app by its location.';

  @override
  late final ObjectSchema<String> input = S.object(
    fields: {
      'location': S.string(
        description: 'The location to open, such as /items/42.',
        minLength: 1,
      ),
    },
    build: (v) => v['location'] as String,
  );

  @override
  bool get readOnly => true;

  @override
  List<String> get failureCodes => const [
    'unknown_route',
    'navigation_unavailable',
  ];

  @override
  Future<String> run(String input, ActionContext context) async {
    final navigate = appContext.onNavigate;
    if (navigate == null) {
      throw const ActionFailure(
        'navigation_unavailable',
        'This app has not connected its router to the assistant.',
      );
    }
    if (!appContext.matchesRoute(input)) {
      throw ActionFailure(
        'unknown_route',
        'No screen matches "$input".',
        details: {'routes': appContext.screens.keys.toList()},
      );
    }
    await navigate(input);
    return input;
  }

  @override
  Object? encode(String output) => {'opened': output};
}
