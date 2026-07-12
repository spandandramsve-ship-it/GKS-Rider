/// Environment configuration for GKS Rider.
///
/// Selects base URL and socket URL based on `--dart-define=ENV=<env>`.
/// Defaults to `dev` (Android emulator pointing at host machine).
class Env {
  Env._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isDev => _env == 'dev' || _env == 'ios' || _env == 'local';
  static bool get isProd => _env == 'prod';

  /// REST API base URL (includes /api/v1).
  static String get baseUrl {
    switch (_env) {
      case 'ios':
        return 'http://localhost:5000/api/v1';
      case 'local':
        // Replace with your LAN IP for physical-device testing.
        return 'http://192.168.1.100:5000/api/v1';
      case 'prod':
        return 'http://187.127.171.117/api/v1';
      case 'dev':
      default:
        return 'http://10.0.2.2:5000/api/v1';
    }
  }

  /// Socket.io URL (host root, no /api/v1 suffix).
  static String get socketUrl {
    switch (_env) {
      case 'ios':
        return 'http://localhost:5000';
      case 'local':
        return 'http://192.168.1.100:5000';
      case 'prod':
        return 'http://187.127.171.117';
      case 'dev':
      default:
        return 'http://10.0.2.2:5000';
    }
  }
}
