import 'package:flutter/material.dart';
import 'package:nbe_payment_flutter_plugin/nbe_payment_flutter_plugin.dart';

import 'debug_info_card.dart';
import 'event_log.dart';
import 'form_widgets.dart';
import 'operation_outcome.dart';

/// Manual test screen for the plugin. Uses only the public plugin API, exactly as a host app
/// would.
///
/// Merchant and session values come from the MTF test environment (for example a session
/// created with the Postman collection in example/postman). Nothing is stored; values live
/// only while the app runs.
class PaymentTestPage extends StatefulWidget {
  const PaymentTestPage({super.key});

  @override
  State<PaymentTestPage> createState() => _PaymentTestPageState();
}

class _PaymentTestPageState extends State<PaymentTestPage>
    with WidgetsBindingObserver {
  final _gateway = NbePaymentGateway();

  // Defaults to the test environment; any other region asks for confirmation before use.
  GatewayRegion _region = GatewayRegion.mtf;

  final _merchantId = TextEditingController(text: 'TESTONELYMOSDK');
  final _merchantName = TextEditingController(text: 'onelymo');
  final _merchantUrl = TextEditingController(text: 'https://onelymo.com');
  // Google Pay needs a Google merchant ID only outside the test environment; Apple Pay always
  // needs a merchant identifier.
  final _googlePayMerchantId = TextEditingController();
  final _applePayMerchantIdentifier = TextEditingController();

  final _sessionId = TextEditingController();
  final _orderId = TextEditingController();
  final _amount = TextEditingController();
  final _currency = TextEditingController(text: 'EGP');
  final _apiVersion = TextEditingController(text: '100');

  // Public Mastercard Gateway test card; not a real card.
  final _cardNumber = TextEditingController(text: '5123450000000008');
  final _expiryMonth = TextEditingController(text: '01');
  final _expiryYear = TextEditingController(text: '39');
  final _securityCode = TextEditingController(text: '100');
  final _nameOnCard = TextEditingController(text: 'Test User');

  final _authenticationTransactionId = TextEditingController();

  final _walletMerchantDisplayName = TextEditingController(
    text: 'NBE Plugin Example',
  );
  final _walletCountryCode = TextEditingController(text: 'EG');

  late final List<TextEditingController> _controllers = [
    _merchantId,
    _merchantName,
    _merchantUrl,
    _googlePayMerchantId,
    _applePayMerchantIdentifier,
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
    _authenticationTransactionId,
    _walletMerchantDisplayName,
    _walletCountryCode,
  ];

  final List<EventLogEntry> _events = [];
  OperationOutcome _outcome = OperationOutcome.idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // Background/foreground transitions are logged so lifecycle tests (e.g. leaving the app
  // while the OTP screen is open) can be read from the event log.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _log('App lifecycle: ${state.name}');
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
    securityCode: _securityCode.text.trim(),
    nameOnCard: _optional(_nameOnCard.text),
  );

  WalletPaymentRequest get _walletRequest => WalletPaymentRequest(
    merchantDisplayName: _walletMerchantDisplayName.text.trim(),
    countryCode: _walletCountryCode.text.trim(),
  );

  // ---------------------------------------------------------------------------------------
  // Plugin operations
  // ---------------------------------------------------------------------------------------

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
          wallet: WalletConfiguration(
            googlePayMerchantId: _optional(_googlePayMerchantId.text),
            applePayMerchantIdentifier: _optional(
              _applePayMerchantIdentifier.text,
            ),
          ),
        ),
      );
      return const OperationOutcome.success('Initialized');
    });
  }

  Future<void> _updateSessionWithCard() =>
      _run('Update session with card', () async {
        // Only the masked form of the card is logged.
        _log('Card: $_card');
        await _gateway.updateSessionWithCard(_session, _card);
        return const OperationOutcome.success('Session updated with card');
      });

  // Saved-card flow: the merchant server already put the stored card in the session, so only
  // the CVV the payer typed is added here. The card fields above are not sent.
  Future<void> _updateSessionWithSecurityCode() =>
      _run('Update session with security code', () async {
        await _gateway.updateSessionWithSecurityCode(
          _session,
          _securityCode.text.trim(),
        );
        return const OperationOutcome.success(
          'Session updated with the security code only',
        );
      });

  Future<void> _authenticatePayer() => _run('Authenticate payer', () async {
    final result = await _gateway.authenticatePayer(
      _session,
      authenticationTransactionId: _optional(_authenticationTransactionId.text),
    );
    final details = [
      'Authentication transaction ID: ${result.authenticationTransactionId}',
      'Authentication performed: ${result.authenticationPerformed}',
      'Challenge (OTP) shown: ${result.challengePerformed}',
      if (result case AuthenticationProceed(:final threeDS2TransactionStatus?))
        '3DS2 status: $threeDS2TransactionStatus',
    ].join('\n');

    return switch (result) {
      AuthenticationProceed() => OperationOutcome.success('PROCEED\n$details'),
      AuthenticationNotProceeded(
        reason: AuthenticationDeclineReason.cancelledByUser,
      ) =>
        OperationOutcome.cancelled('NOT PROCEEDED (cancelledByUser)\n$details'),
      AuthenticationNotProceeded(:final reason) => OperationOutcome(
        OperationStatus.failed,
        'NOT PROCEEDED (${reason.name})\n$details',
      ),
    };
  });

  Future<void> _checkWallet() => _run('Check available wallet', () async {
    final wallet = await _gateway.getAvailableWallet(_walletRequest);
    return OperationOutcome.success('Available wallet: ${wallet.name}');
  });

  Future<void> _payWithWallet() => _run('Pay with device wallet', () async {
    final result = await _gateway.payWithDeviceWallet(_session, _walletRequest);
    return switch (result) {
      WalletPaymentCompleted(:final wallet, :final cardDescription) =>
        OperationOutcome.success(
          'Session updated with ${wallet.name} '
          '(${cardDescription ?? 'no card description'})',
        ),
      WalletPaymentCancelled(:final wallet) => OperationOutcome.cancelled(
        '${wallet.name} sheet cancelled',
      ),
    };
  });

  // ---------------------------------------------------------------------------------------
  // Error and concurrency scenarios
  // ---------------------------------------------------------------------------------------

  Future<void> _tryBeforeInitialization() =>
      _run('Operation before initialization', () async {
        if (_gateway.isInitialized) {
          return const OperationOutcome(
            OperationStatus.idle,
            'The gateway is already initialized in this app process. '
            'Restart the app and run this scenario before Initialize.',
          );
        }
        await _gateway.updateSessionWithCard(_session, _card);
        return const OperationOutcome.success('Unexpected: no error');
      });

  Future<void> _tryInvalidCard() => _run('Invalid card number', () async {
    await _gateway.updateSessionWithCard(
      _session,
      const CardDetails(
        number: '1234',
        expiryMonth: '01',
        expiryYear: '39',
        securityCode: '100',
      ),
    );
    return const OperationOutcome.success('Unexpected: no error');
  });

  Future<void> _tryUnsupportedApiVersion() =>
      _run('Unsupported API version', () async {
        final session = _session;
        await _gateway.updateSessionWithCard(
          PaymentSession(
            id: session.id,
            orderId: session.orderId,
            amount: session.amount,
            currency: session.currency,
            apiVersion: '60',
          ),
          _card,
        );
        return const OperationOutcome.success('Unexpected: no error');
      });

  Future<void> _tryUnknownSession() => _run('Unknown session', () async {
    final session = _session;
    await _gateway.updateSessionWithCard(
      PaymentSession(
        id: 'SESSION0000000000000000000000000',
        orderId: session.orderId.isEmpty ? 'ORDER-TEST' : session.orderId,
        amount: session.amount.isEmpty ? '1.00' : session.amount,
        currency: session.currency,
        apiVersion: session.apiVersion,
      ),
      _card,
    );
    return const OperationOutcome.success('Unexpected: no error');
  });

  Future<void>
  _tryReservedGatewayField() => _run('Card data in additional fields', () async {
    // Rejected before anything is sent: card data may only travel through CardDetails.
    GatewayFields().setString('sourceOfFunds.provided.card.number', '1234');
    return const OperationOutcome.success('Unexpected: no error');
  });

  /// Starts the same operation twice without waiting, as a double tap would. The plugin must
  /// run the first one and reject the second with `operationInProgress`, regardless of the UI.
  Future<void> _tryDoubleCall() async {
    _log('Double call: starting two card updates at once');
    _setOutcome(
      const OperationOutcome(OperationStatus.processing, 'Double call'),
    );

    Future<String> attempt(String name) async {
      try {
        await _gateway.updateSessionWithCard(_session, _card);
        return '$name: success';
      } on GatewayException catch (error) {
        return '$name: ${error.code.name}';
      }
    }

    final results = await Future.wait([attempt('First'), attempt('Second')]);
    results.forEach(_log);
    _setOutcome(OperationOutcome(OperationStatus.success, results.join('\n')));
  }

  // ---------------------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------------------

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

  Future<void> _run(
    String name,
    Future<OperationOutcome> Function() operation,
  ) async {
    _setOutcome(
      OperationOutcome(OperationStatus.processing, 'Processing: $name'),
    );
    _log('$name started');
    try {
      final outcome = await operation();
      _log('$name → ${outcome.status.name}: ${outcome.message}');
      _setOutcome(outcome);
    } on GatewayException catch (error) {
      _log('$name failed: $error', isError: true);
      _setOutcome(OperationOutcome(OperationStatus.failed, _describe(error)));
    } catch (error) {
      // The plugin should only throw GatewayException; anything else is a plugin bug and is
      // shown as such instead of being hidden. Only the type is shown.
      _log('$name failed with unexpected ${error.runtimeType}', isError: true);
      _setOutcome(
        OperationOutcome(
          OperationStatus.failed,
          'Unexpected error type: ${error.runtimeType}',
        ),
      );
    }
  }

  String _describe(GatewayException error) => [
    'Error code: ${error.code.name}',
    error.message,
    if (error.httpStatusCode != null) 'HTTP status: ${error.httpStatusCode}',
    if (error.nativeDetails != null) 'Native details: ${error.nativeDetails}',
  ].join('\n');

  void _setOutcome(OperationOutcome outcome) {
    if (mounted) setState(() => _outcome = outcome);
  }

  void _log(String message, {bool isError = false}) {
    if (!mounted) return;
    setState(() => _events.add(EventLogEntry(message, isError: isError)));
  }

  static String? _optional(String value) =>
      value.trim().isEmpty ? null : value.trim();

  // ---------------------------------------------------------------------------------------
  // Layout
  // ---------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NBE Payment Plugin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EnvironmentBanner(
            region: _region,
            isInitialized: _gateway.isInitialized,
          ),
          const SizedBox(height: 16),
          FormSection(
            title: 'Last result',
            children: [OperationOutcomeView(outcome: _outcome)],
          ),
          FormSection(
            title: '1. Initialization',
            description:
                'Once per app process. A different configuration needs an app restart.',
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
              LabeledTextField(controller: _merchantId, label: 'Merchant ID'),
              LabeledTextField(
                controller: _merchantName,
                label: 'Merchant name (used by Android only)',
              ),
              LabeledTextField(
                controller: _merchantUrl,
                label: 'Merchant URL (used by Android only)',
                keyboardType: TextInputType.url,
              ),
              LabeledTextField(
                controller: _googlePayMerchantId,
                label: 'Google Pay merchant ID (Android, optional in test)',
              ),
              LabeledTextField(
                controller: _applePayMerchantIdentifier,
                label: 'Apple Pay merchant identifier (iOS only)',
              ),
              FilledButton(
                onPressed: _initialize,
                child: const Text('Initialize'),
              ),
            ],
          ),
          FormSection(
            title: '2. Session',
            description:
                'Created by your server (or Postman) on the same region as above.',
            children: [
              LabeledTextField(controller: _sessionId, label: 'Session ID'),
              LabeledTextField(controller: _orderId, label: 'Order ID'),
              Row(
                children: [
                  Expanded(
                    child: LabeledTextField(
                      controller: _amount,
                      label: 'Amount',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LabeledTextField(
                      controller: _currency,
                      label: 'Currency',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LabeledTextField(
                      controller: _apiVersion,
                      label: 'API version',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
          FormSection(
            title: '3. Card',
            description: 'Prefilled with a public Mastercard test card.',
            children: [
              LabeledTextField(
                controller: _cardNumber,
                label: 'Card number',
                keyboardType: TextInputType.number,
              ),
              Row(
                children: [
                  Expanded(
                    child: LabeledTextField(
                      controller: _expiryMonth,
                      label: 'MM',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LabeledTextField(
                      controller: _expiryYear,
                      label: 'YY',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LabeledTextField(
                      controller: _securityCode,
                      label: 'CVV',
                      obscureText: true,
                    ),
                  ),
                ],
              ),
              LabeledTextField(controller: _nameOnCard, label: 'Name on card'),
              FilledButton(
                onPressed: _updateSessionWithCard,
                child: const Text('Update session with card'),
              ),
            ],
          ),
          FormSection(
            title: '3b. Saved card (CVV only)',
            description:
                'For a session the server already filled with a saved card (card_id). '
                'Sends only the CVV typed above; the card number, expiry and name are '
                'not sent, so the stored card stays in the session.',
            children: [
              FilledButton(
                onPressed: _updateSessionWithSecurityCode,
                child: const Text('Update session with security code'),
              ),
            ],
          ),
          FormSection(
            title: '4. 3-D Secure',
            description:
                'May show the issuer challenge (OTP) screen. Copy the transaction ID to the server Pay request.',
            children: [
              LabeledTextField(
                controller: _authenticationTransactionId,
                label:
                    'Authentication transaction ID (optional, generated if empty)',
              ),
              FilledButton(
                onPressed: _authenticatePayer,
                child: const Text('Authenticate payer'),
              ),
            ],
          ),
          FormSection(
            title: '5. Device wallet',
            description:
                'Google Pay on Android, Apple Pay on iOS. Uses the session above.',
            children: [
              LabeledTextField(
                controller: _walletMerchantDisplayName,
                label: 'Name shown on the wallet sheet',
              ),
              LabeledTextField(
                controller: _walletCountryCode,
                label: 'Merchant country code',
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _checkWallet,
                    child: const Text('Check available wallet'),
                  ),
                  FilledButton(
                    onPressed: _payWithWallet,
                    child: const Text('Pay with device wallet'),
                  ),
                ],
              ),
            ],
          ),
          FormSection(
            title: 'Error and concurrency scenarios',
            description:
                'Each scenario must end with the error code shown next to it.',
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: _tryBeforeInitialization,
                    child: const Text('Before initialize → notInitialized'),
                  ),
                  OutlinedButton(
                    onPressed: _tryInvalidCard,
                    child: const Text('Invalid card → invalidArgument'),
                  ),
                  OutlinedButton(
                    onPressed: _tryUnsupportedApiVersion,
                    child: const Text('API version 60 → invalidApiVersion'),
                  ),
                  OutlinedButton(
                    onPressed: _tryUnknownSession,
                    child: const Text('Unknown session → gatewayRejected'),
                  ),
                  OutlinedButton(
                    onPressed: _tryReservedGatewayField,
                    child: const Text('Card in extra fields → invalidArgument'),
                  ),
                  OutlinedButton(
                    onPressed: _tryDoubleCall,
                    child: const Text('Double call → operationInProgress'),
                  ),
                ],
              ),
            ],
          ),
          EventLogView(
            entries: _events,
            onClear: () => setState(_events.clear),
          ),
          const SizedBox(height: 16),
          FormSection(
            title: 'Debug information',
            children: [
              DebugInfoCard(
                region: _region,
                isInitialized: _gateway.isInitialized,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
