import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/models/solar_panel_model.dart';

class ArSolarNativeService {
  ArSolarNativeService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'com.imt.greenenergy/ar_solar';

  final MethodChannel _channel;

  bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  Future<void> openConfigurator({
    required SolarPanelModel panel,
    required String authToken,
    required String apiBaseUrl,
  }) async {
    if (!isAndroid) {
      throw PlatformException(
        code: 'unsupported_platform',
        message:
            'The rooftop designer and Google Scene Viewer are Android-only for now.',
      );
    }

    await _channel.invokeMethod<void>('openConfigurator', {
      'id': panel.id,
      'companyName': panel.companyName,
      'widthM': panel.widthM,
      'lengthM': panel.lengthM,
      'minWatts': panel.minWatts,
      'maxWatts': panel.maxWatts,
      'defaultWatts': panel.defaultWatts,
      'wattStep': panel.wattStep,
      'authToken': authToken,
      'apiBaseUrl': apiBaseUrl,
    });
  }
}
