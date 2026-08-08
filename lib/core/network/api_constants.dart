enum Environment { uat, prod }

class ApiConstants {
  /// Change only here.
  static const Environment current = Environment.uat;

  static String get baseUrl {
    switch (current) {
      case Environment.uat:
        return 'https://uat-imt-solar-360.immortalgroup.in/api';
      case Environment.prod:
        return 'https://imt-billbook.immortalgroup.in/api';
    }
  }
}
