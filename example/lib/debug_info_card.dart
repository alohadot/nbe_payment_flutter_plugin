import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

/// Information useful when reporting a test result. Everything here is known locally; the
/// plugin exposes no extra API for it.
class DebugInfoCard extends StatelessWidget {
  const DebugInfoCard({
    super.key,
    required this.region,
    required this.isInitialized,
  });

  final GatewayRegion region;
  final bool isInitialized;

  @override
  Widget build(BuildContext context) {
    final platform = defaultTargetPlatform;
    final nativeSdk = switch (platform) {
      TargetPlatform.android =>
        'Mastercard Gateway Android SDK ${NbePaymentVersions.androidGatewaySdk}',
      TargetPlatform.iOS =>
        'Mastercard Gateway iOS SDK ${NbePaymentVersions.iosGatewaySdk}',
      _ => 'Not supported on this platform',
    };

    final rows = {
      'Platform': platform.name,
      'Plugin': NbePaymentVersions.plugin,
      'Native SDK': nativeSdk,
      'Region': region.name,
      'Environment': region == GatewayRegion.mtf ? 'Test (MTF)' : 'Production',
      'Initialized': isInitialized ? 'yes' : 'no',
      'Build mode': kReleaseMode
          ? 'release'
          : (kProfileMode ? 'profile' : 'debug'),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final MapEntry(:key, :value) in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        key,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: SelectableText(value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
