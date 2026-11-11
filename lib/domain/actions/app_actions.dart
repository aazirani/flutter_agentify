import 'package:flutter_agentify_core/flutter_agentify_core.dart';

// @example:begin
import '../repositories/items_repository.dart';
// @example:end
import '../repositories/secret_store.dart';
import '../repositories/settings_repository.dart';
// @example:begin
import 'items_actions.dart';
// @example:end
import 'settings_actions.dart';

/// Every action of the app. Screens call these through the registry; the
/// assistant and the action CLI call them by name.
class AppActions {
  AppActions({
    required SettingsRepository settings,
    required SecretStore secrets,
    required ApprovalPrefs approvals,
    this.serverEditable = true,
    // @on-device:begin
    this.deviceOptional = true,
    OnDeviceModelLookup onDeviceModel = _noModel,
    // @on-device:end
    // @example:begin
    required ItemsRepository items,
    // @example:end
  }) : setThemeMode = SetThemeMode(settings),
       setLanguage = SetLanguage(settings),
       setAssistantProvider = SetAssistantProvider(settings),
       setApiKey = SetApiKey(secrets),
       // @on-device:begin
       downloadOnDeviceModel = DownloadOnDeviceModel(onDeviceModel),
       cancelOnDeviceModelDownload = CancelOnDeviceModelDownload(onDeviceModel),
       deleteOnDeviceModel = DeleteOnDeviceModel(onDeviceModel),
       dismissOnDeviceOffer = DismissOnDeviceOffer(settings),
       setUseOnDeviceModel = SetUseOnDeviceModel(settings, onDeviceModel),
       // @on-device:end
       // @example:begin
       resetApprovals = ResetApprovals(approvals),
       listItems = ListItems(items),
       getItem = GetItem(items),
       createItem = CreateItem(items),
       updateItem = UpdateItem(items),
       deleteItem = DeleteItem(items),
       deleteItems = DeleteItems(items);
  // @example:end
  // @empty: resetApprovals = ResetApprovals(approvals);

  /// False: the setup file's server is final, or the app uses no server,
  /// so the actions that change it are not registered.
  final bool serverEditable;
  // @on-device:begin

  /// False: only the in-app model answers (`ModelMode.onDevice`), so the
  /// switch between it and the server is not registered.
  final bool deviceOptional;
  // @on-device:end

  final SetThemeMode setThemeMode;
  final SetLanguage setLanguage;
  final SetAssistantProvider setAssistantProvider;
  final SetApiKey setApiKey;
  final ResetApprovals resetApprovals;
  // @on-device:begin
  final DownloadOnDeviceModel downloadOnDeviceModel;
  final CancelOnDeviceModelDownload cancelOnDeviceModelDownload;
  final DeleteOnDeviceModel deleteOnDeviceModel;
  final DismissOnDeviceOffer dismissOnDeviceOffer;
  final SetUseOnDeviceModel setUseOnDeviceModel;
  // @on-device:end
  // @example:begin
  final ListItems listItems;
  final GetItem getItem;
  final CreateItem createItem;
  final UpdateItem updateItem;
  final DeleteItem deleteItem;
  final DeleteItems deleteItems;
  // @example:end

  List<AgentAction<Object?, Object?>> get all => [
    setThemeMode,
    setLanguage,
    if (serverEditable) ...[setAssistantProvider, setApiKey],
    resetApprovals,
    // @on-device:begin
    downloadOnDeviceModel,
    cancelOnDeviceModelDownload,
    deleteOnDeviceModel,
    dismissOnDeviceOffer,
    if (deviceOptional) setUseOnDeviceModel,
    // @on-device:end
    // @example:begin
    listItems,
    getItem,
    createItem,
    updateItem,
    deleteItem,
    deleteItems,
    // @example:end
  ];
}

// @on-device:begin
OnDeviceModelController? _noModel() => null;
// @on-device:end

/// The registry the UI, the assistant and the CLI share: the app's actions
/// plus the built-in ones.
ActionRegistry buildActionRegistry(
  AppActions actions, {
  required AppContext appContext,
  required MemoryStore memories,
}) => ActionRegistry([
  ...actions.all,
  ...builtInActions(appContext: appContext, memories: memories),
]);
