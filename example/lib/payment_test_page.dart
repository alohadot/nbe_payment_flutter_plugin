import 'package:flutter/material.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

import 'event_log.dart';

/// Manual test screen for the plugin. Uses only the public plugin API, exactly as a host
/// app would.
///
/// Merchant and session values come from the MTF test environment (for example a session
/// created with Postman). Nothing is stored; values live only while the app runs.
class PaymentTestPage extends StatefulWidget {
  const PaymentTestPage({super.key});

  @override
  State<PaymentTestPage> createState() => _PaymentTestPageState();
}

class _PaymentTestPageState extends State<PaymentTestPage> {
  final _gateway = NbePaymentGateway();

  // Defaults to the test environment; any other region asks for confirmation before use.
  GatewayRegion _region = GatewayRegion.mtf;

  final _merchantId = TextEditingController(text: 'TESTONELYMOSDK');
  final _merchantName = TextEditingController(text: 'onelymo');
  final _merchantUrl = TextEditingController(text: 'https://onelymo.com');

  final _sessionId = TextEditingController();
  final _orderId = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  final _apiVersion = TextEditingController();

  // Public Mastercard Gateway test card; not a real card.
  final _cardNumber = TextEditingController(text: '5123450000000008');
  final _expiryMonth = TextEditingController(text: '01');
  final _expiryYear = TextEditingController(text: '39');
  final _securityCode = TextEditingController(text: '100');
  final _nameOnCard = TextEditingController(text: 'Test User');

  final List<EventLogEntry> _events = [];
  String _lastResult = 'Idle';
  bool _isBusy = false;

  @override
  void dispose() {
    for (final controller in [
      _merchantId,
      _merchantName,
      _merchantUrl,
      _sessionId,
      _orderId,
      _amount,
      _currency,
      _apiVersion,
      _cardNumber,
      _expiryMonth,
      _expiryYear,
      _securityCode,
      _nameOnCard,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  PaymentSession get _session => PaymentSession(
    id: _sessionId.text.trim(),
    orderId: _orderId.text.trim(),
    amount: _amount.text.trim(),
    currency: _currency.text.trim(),
    apiVersion: _apiVersion.text.trim(),
  );

  CardDetails get _card => CardDetails(
    number: _cardNumber.text.trim(),
    expiryMonth: _expiryMonth.text.trim(),
    expiryYear: _expiryYear.text.trim(),
    securityCode: _optional(_securityCode.text),
    nameOnCard: _optional(_nameOnCard.text),
  );

  Future<void> _initialize() async {
    final region = _region;
    if (region != GatewayRegion.mtf &&
        !await _confirmProductionRegion(region)) {
      _log('Initialize cancelled: ${region.name} region not confirmed');
      return;
    }
    await _run('Initialize (${region.name})', () async {
      await _gateway.initialize(
        GatewayConfiguration(
          merchantId: _merchantId.text.trim(),
          merchantName: _merchantName.text.trim(),
          merchantUrl: _merchantUrl.text.trim(),
          region: region,
        ),
      );
      return 'Initialized';
    });
  }

  Future<bool> _confirmProductionRegion(GatewayRegion region) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Production region'),
        content: Text(
          '"${region.name}" is not the test environment. '
          'Payments made after initializing can move real money.\n\n'
          'Continue only with a production merchant you are allowed to use.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('I understand, continue'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _updateSessionWithCard() =>
      _run('Update session with card', () async {
        // Only the masked form of the card is logged.
        _log('Card: $_card');
        await _gateway.updateSessionWithCard(_session, _card);
        return 'Session updated with card';
      });

  Future<void> _run(String name, Future<String> Function() operation) async {
    setState(() {
      _isBusy = true;
      _lastResult = 'Processing: $name';
    });
    _log('$name started');
    try {
      final result = await operation();
      _log('$name succeeded: $result');
      _setResult('Success: $result');
    } on GatewayException catch (error) {
      _log('$name failed: $error', isError: true);
      _setResult(_describe(error));
    } catch (error) {
      // The plugin should only throw GatewayException; anything else is a plugin bug and
      // is shown as such instead of being hidden. Only the type is shown.
      _log('$name failed with unexpected ${error.runtimeType}', isError: true);
      _setResult('Unexpected error: ${error.runtimeType}');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _describe(GatewayException error) => [
    'Failed: ${error.code.name}',
    error.message,
    if (error.httpStatusCode != null) 'HTTP status: ${error.httpStatusCode}',
    if (error.nativeDetails != null) 'Native details: ${error.nativeDetails}',
  ].join('\n');

  void _setResult(String result) {
    if (mounted) setState(() => _lastResult = result);
  }

  void _log(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => _events.add(EventLogEntry(message, isError: isError)));
  }

  static String? _optional(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('NBE Payment Plugin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _EnvironmentBanner(
            region: _region,
            isInitialized: _gateway.isInitialized,
          ),
          const SizedBox(height: 16),
          _Section(
            title: 'Initialization',
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: DropdownButtonFormField<GatewayRegion>(
                  initialValue: _region,
                  decoration: const InputDecoration(
                    labelText: 'Region',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final region in GatewayRegion.values)
                      DropdownMenuItem(
                        value: region,
                        child: Text(
                          region == GatewayRegion.mtf
                              ? 'mtf (test environment)'
                              : '${region.name} (production)',
                        ),
                      ),
                  ],
                  onChanged: (region) {
                    if (region != null) setState(() => _region = region);
                  },
                ),
              ),
              _field(_merchantId, 'Merchant ID'),
              _field(_merchantName, 'Merchant name (used by Android only)'),
              _field(
                _merchantUrl,
                'Merchant URL (used by Android only)',
                keyboardType: TextInputType.url,
              ),
              FilledButton(
                onPressed: _initialize,
                child: const Text('Initialize'),
              ),
            ],
          ),
          _Section(
            title: 'Session (from your server / Postman)',
            children: [
              _field(_sessionId, 'Session ID'),
              _field(_orderId, 'Order ID'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      _amount,
                      'Amount',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_currency, 'Currency')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(
                      _apiVersion,
                      'API version',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _Section(
            title: 'Card (test card)',
            children: [
              _field(
                _cardNumber,
                'Card number',
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(child: _field(_expiryMonth, 'MM')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_expiryYear, 'YY')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _field(_securityCode, 'CVV', obscureText: true),
                  ),
                ],
              ),
              _field(_nameOnCard, 'Name on card'),
              FilledButton(
                onPressed: _updateSessionWithCard,
                child: const Text('Update session with card'),
              ),
            ],
          ),
          _Section(
            title: 'Last result',
            children: [
              if (_isBusy) const LinearProgressIndicator(),
              SelectableText(_lastResult, style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          EventLogView(
            entries: _events,
            onClear: () => setState(_events.clear),
          ),
          const SizedBox(height: 24),
          Text(
            'Plugin ${NbePaymentVersions.plugin} · '
            'Android SDK ${NbePaymentVersions.androidGatewaySdk} · '
            'iOS SDK ${NbePaymentVersions.iosGatewaySdk}',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner({required this.region, required this.isInitialized});

  final GatewayRegion region;
  final bool isInitialized;

  @override
  Widget build(BuildContext context) {
    final isTest = region == GatewayRegion.mtf;
    final background = isTest ? Colors.amber.shade100 : Colors.red.shade100;
    final border = isTest ? Colors.amber.shade700 : Colors.red.shade700;
    final headline = isTest
        ? 'MTF TEST ENVIRONMENT — no real money moves'
        : 'PRODUCTION REGION (${region.name.toUpperCase()}) — REAL MONEY';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border, width: isTest ? 1 : 3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$headline\n'
        'Gateway initialized: ${isInitialized ? 'yes' : 'no'}',
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
