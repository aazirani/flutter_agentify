/// The doctor: static checks that keep a Flutter Agentify repo healthy.
///
/// Run it with `dart run flutter_agentify_core:doctor`.
library;

export 'src/doctor/checks/agent_files_check.dart';
export 'src/doctor/checks/bundled_secrets_check.dart';
export 'src/doctor/checks/doc_links_check.dart';
export 'src/doctor/checks/migrations_check.dart';
export 'src/doctor/checks/ratchet_check.dart';
export 'src/doctor/checks/skills_check.dart';
export 'src/doctor/doctor.dart';
