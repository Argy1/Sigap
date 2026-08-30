/// Package bersama App Pasien & App Sopir.
///
/// Berisi seluruh sistem desain **"Dispatch Console"**, model data, API client,
/// layanan realtime, dan provider Riverpod. Kedua aplikasi mengimpor package
/// ini saja — itulah yang menjamin keduanya terlihat dan berperilaku identik.
///
/// Baca `/design-reference/README.md` sebelum menambah widget baru di sini.
library;

// Tema
export 'src/theme/dispatch_colors.dart';
export 'src/theme/dispatch_theme.dart';
export 'src/theme/dispatch_typography.dart';

// Model
export 'src/models/models.dart';

// API & realtime
export 'src/api/api_client.dart';
export 'src/api/token_storage.dart';
export 'src/realtime/events.dart';
export 'src/realtime/socket_service.dart';

// Provider
export 'src/providers/core_providers.dart';

// Widget
export 'src/widgets/dispatch_map.dart';
export 'src/widgets/dispatch_nav_bar.dart';
export 'src/widgets/dispatch_widgets.dart';
export 'src/widgets/pulse_stepper.dart';
export 'src/widgets/reticle_bracket.dart';
export 'src/widgets/sos_hold_button.dart';

// Utilitas
export 'src/utils/format.dart';
export 'src/utils/geo.dart';
