enum Environment { local, uat, prod }

class ApiConstants {
  /// Change only here.
  static const Environment current = Environment.uat;

  static String get baseUrl {
    switch (current) {
      case Environment.local:
        // Phone must use the PC's LAN address. localhost would be the phone itself.
        return 'http://192.168.1.21:3004/api';
      case Environment.uat:
        return 'https://uat-imt-billbook.immortalgroup.in/api';
      case Environment.prod:
        return 'https://imt-billbook.immortalgroup.in/api';
    }
  }
}
