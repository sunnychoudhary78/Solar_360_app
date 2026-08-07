enum Environment { uat, prod }

class ApiConstants {
  /// Change only here.
  static const Environment current = Environment.prod;

  static String get baseUrl {
    switch (current) {
      case Environment.uat:
        return 'http://192.168.1.26:3004/api';
      case Environment.prod:
        return 'https://imt-billbook.immortalgroup.in/api';
    }
  }
}
