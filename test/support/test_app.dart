import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_agentify/ai/assistant_providers.dart';
import 'package:flutter_agentify/ai/assistant_setup.dart';
import 'package:flutter_agentify/ai/model_route.dart';
// @on-device:begin
import 'package:flutter_agentify/ai/on_device_model.dart';
// @on-device:end
import 'package:flutter_agentify/ai/change_event_adapter.dart';
import 'package:flutter_agentify/ai/go_router_adapter.dart';
import 'package:flutter_agentify/ai/screen_contexts.dart';
import 'package:flutter_agentify/data/repositories/in_memory_secret_store.dart';
import 'package:flutter_agentify/data/repositories/in_memory_settings_repository.dart';
import 'package:flutter_agentify/di/service_locator.dart';
import 'package:flutter_agentify/domain/actions/app_actions.dart';
import 'package:flutter_agentify/domain/entities/assistant_settings.dart';
import 'package:flutter_agentify/domain/entities/language/supported_languages.dart';
// @example:begin
import 'package:flutter_agentify/domain/repositories/items_repository.dart';
// @example:end
import 'package:flutter_agentify/domain/repositories/secret_store.dart';
import 'package:flutter_agentify/domain/repositories/settings_repository.dart';
import 'package:flutter_agentify/presentation/assistant/assistant_toggle_button.dart';
import 'package:flutter_agentify/presentation/home/home_screen.dart';
import 'package:flutter_agentify/presentation/my_app.dart';
import 'package:flutter_agentify/presentation/providers/language_provider.dart';
import 'package:flutter_agentify/utils/locale/app_localization.dart';
import 'package:flutter_agentify/utils/routes/app_router.dart';
import 'package:flutter_agentify_core/flutter_agentify_core.dart';
import 'package:flutter_agentify_core/testing.dart';
import 'package:flutter_agentify_ui/flutter_agentify_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

// @example:begin
import 'fakes.dart';

// @example:end

/// Registers in-memory parts and the real actions and registry in get_it,
/// and returns a container wired to the change events.
ProviderContainer setUpTestServices({
  SettingsRepository? settings,
  SecretStore? secrets,
  List<Override> overrides = const [],
  Map<String, ScreenContext>? screens,
  AssistantSetup? setup,
  // @on-device:begin
  OnDeviceEngine? onDeviceEngine,
  LoadMarker? loadMarker,
  // @on-device:end
  ThreadStore? threads,
  // @example:begin
  ItemsRepository? items,
  // @example:end
}) {
  // Each test resets get_it in its tear-down, so this one starts empty.
  final getIt = ServiceLocator.getIt;
  // @example:begin
  final itemsRepository = items ?? FakeItemsRepository();
  // @example:end
  final settingsRepository = settings ?? InMemorySettingsRepository();
  final secretStore = secrets ?? InMemorySecretStore();
  final approvals = InMemoryApprovalPrefs();
  // Tests talk to a scripted server unless they choose a mode, so the
  // same tests pass whichever mode the project was set up with.
  final activeSetup =
      setup ??
      AssistantSetup(mode: ModelMode.server, server: assistantSetup.server);
  late final ProviderContainer container;
  final actions = AppActions(
    settings: settingsRepository,
    secrets: secretStore,
    approvals: approvals,
    serverEditable: activeSetup.usesServer && activeSetup.server.userEditable,
    // @on-device:begin
    onDeviceModel: () => container.read(onDeviceModelProvider),
    deviceOptional: (setup ?? assistantSetup).mode == ModelMode.both,
    // @on-device:end
    // @example:begin
    items: itemsRepository,
    // @example:end
  );
  // Filled with the real screen table once the container exists.
  final screenTable = <String, ScreenContext>{...?screens};
  final appContext = AppContext(screens: screenTable);
  final memories = InMemoryMemoryStore();
  final registry = buildActionRegistry(
    actions,
    appContext: appContext,
    memories: memories,
  );
  getIt
    ..registerSingleton<SettingsRepository>(settingsRepository)
    ..registerSingleton<SecretStore>(secretStore)
    ..registerSingleton<ThreadStore>(threads ?? InMemoryThreadStore())
    ..registerSingleton<MemoryStore>(memories)
    ..registerSingleton<ApprovalPrefs>(approvals)
    ..registerSingleton<AssistantInstructions>(
      const AssistantInstructions('Test app.'),
    )
    ..registerSingleton<AppActions>(actions)
    ..registerSingleton<AppContext>(appContext)
    ..registerSingleton<ActionRegistry>(registry);
  // @example:begin
  getIt.registerSingleton<ItemsRepository>(itemsRepository);
  // @example:end
  container = ProviderContainer(
    overrides: [
      ...overrides,
      activeSetupProvider.overrideWithValue(activeSetup),
      // @on-device:begin
      // Tests never reach the real engine: no model is installed.
      onDeviceEngineProvider.overrideWithValue(
        onDeviceEngine ?? FakeOnDeviceEngine(),
      ),
      loadMarkerProvider.overrideWithValue(loadMarker ?? InMemoryLoadMarker()),
      // @on-device:end
    ],
  );
  if (screens == null) screenTable.addAll(buildScreenContexts(container));
  final subscription = attachChangeEvents(registry, container);
  addTearDown(() async {
    await subscription.cancel();
    container.dispose();
    await getIt.reset();
  });
  return container;
}

/// The language the tests' expected texts are written in; tests that look
/// for English text pump in it, whatever the default language is.
const english = Locale('en');

final _defaultLocale = Locale(kSupportedLanguages.first.locale);

final _supportedLocales = [
  for (final language in kSupportedLanguages) Locale(language.locale),
];

/// Language codes written right to left: the set `intl`'s `Bidi` uses, so a
/// test knows the direction to expect without asking Flutter.
/// Add the code here when the app adds a rarer right-to-left language.
const rtlLanguageCodes = {
  'ar',
  'dv',
  'fa',
  'he',
  'iw',
  'nqo',
  'ps',
  'sd',
  'ug',
  'ur',
  'yi',
};

/// Pumps [home] (the home screen by default) inside the app's localization
/// and theme setup, in [locale] or else the default language.
Future<ProviderContainer> pumpTestApp(
  WidgetTester tester, {
  Widget? home,
  SettingsRepository? settings,
  Size? size,
  Locale? locale,
  // @example:begin
  ItemsRepository? items,
  // @example:end
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  final container = setUpTestServices(
    settings: settings,
    // @example:begin
    items: items,
    // @example:end
  );
  // A translation cached by an earlier test is a future from that test's
  // fake time and never completes in this one; load it afresh.
  rootBundle.clear();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale ?? _defaultLocale,
        supportedLocales: _supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home ?? const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Pumps the whole app (router, shell, assistant) on a device set to
/// [locale], or else the default language. When [provider] is given, the
/// assistant talks to it instead of a real model, and the default settings
/// name a model so the session starts.
Future<ProviderContainer> pumpFullApp(
  WidgetTester tester, {
  ScriptedProvider? provider,
  SettingsRepository? settings,
  Size size = const Size(1200, 900),
  Locale? locale,
  AssistantSetup? setup,
  // @on-device:begin
  OnDeviceEngine? onDeviceEngine,
  // @on-device:end
  ThreadStore? threads,
  // @example:begin
  ItemsRepository? items,
  // @example:end
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = <Override>[
    if (provider != null)
      modelConnectorProvider.overrideWithValue(
        ({required presetId, required baseUrl, apiKey}) => provider,
      ),
    deviceLanguageProvider.overrideWithValue(
      (locale ?? _defaultLocale).languageCode,
    ),
  ];
  final container = setUpTestServices(
    settings:
        settings ??
        (provider == null
            ? null
            : (InMemorySettingsRepository()..setAssistantSettings(
                const AssistantSettings(model: 'test'),
              ))),
    overrides: overrides,
    setup: setup,
    // @on-device:begin
    onDeviceEngine: onDeviceEngine,
    // @on-device:end
    threads: threads,
    // @example:begin
    items: items,
    // @example:end
  );
  AppRouter.router.go('/');
  addTearDown(
    attachRouter(AppRouter.router, ServiceLocator.getIt<AppContext>()),
  );
  rootBundle.clear();
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Opens the assistant (side panel or sheet) and sends [text].
Future<void> openAssistant(WidgetTester tester) async {
  await tester.tap(find.byType(AssistantToggleButton).first);
  await tester.pumpAndSettle();
}

Future<void> sendToAssistant(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AssistantChat),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.pump();
  await tester.tap(find.byTooltip('Send'));
  await tester.pumpAndSettle();
}

/// Pumps [home] over an existing [container] (see [setUpTestServices]).
Future<void> pumpTestAppWith(
  WidgetTester tester,
  ProviderContainer container,
  Widget home, {
  Locale? locale,
}) async {
  rootBundle.clear();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale ?? _defaultLocale,
        supportedLocales: _supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The provider container the app under test runs in.
ProviderContainer containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
