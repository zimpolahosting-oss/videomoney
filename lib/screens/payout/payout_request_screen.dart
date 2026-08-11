import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/crypto_payout_text.dart';
import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

enum _PayoutMethod { paypal, revolut, btc, usdc }
enum _PayoutCurrency { eur, gbp, usd }

class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key, this.initialMethod});

  final String? initialMethod;

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _viewsController = TextEditingController();
  final _payPalController = TextEditingController();
  final _revolutController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _ibanController = TextEditingController();
  final _bankAccountNumberController = TextEditingController();
  final _cryptoAddressController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isSubmitting = false;
  late _PayoutMethod _method;
  _PayoutCurrency _currency = _PayoutCurrency.eur;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialMethod ?? '').toLowerCase();
    _method = switch (initial) {
      'revolut' => _PayoutMethod.revolut,
      'btc' => _PayoutMethod.btc,
      'usdc' => _PayoutMethod.usdc,
      _ => _PayoutMethod.paypal,
    };
  }

  @override
  void dispose() {
    _viewsController.dispose();
    _payPalController.dispose();
    _revolutController.dispose();
    _accountHolderController.dispose();
    _bankNameController.dispose();
    _ibanController.dispose();
    _bankAccountNumberController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  String _normalizedViewsInput([String? value]) {
    return (value ?? _viewsController.text).replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final requestedViews = int.parse(_normalizedViewsInput());
      await _firestoreService.createPayoutRequest(
        uid: user.uid,
        coinsRequested: requestedViews,
        payoutMethod: switch (_method) {
          _PayoutMethod.paypal => 'paypal',
          _PayoutMethod.revolut => 'revolut',
          _PayoutMethod.btc => 'btc',
          _PayoutMethod.usdc => 'usdc',
        },
        payPalEmail: _method == _PayoutMethod.paypal ? _payPalController.text : '',
        revolutUsername:
            _method == _PayoutMethod.revolut ? _revolutController.text : '',
        accountHolderName: _accountHolderController.text,
        payoutCurrency: switch (_method) {
          _PayoutMethod.btc => 'BTC',
          _PayoutMethod.usdc => 'USDC',
          _ => _currency.name.toUpperCase(),
        },
        bankName: '',
        iban: '',
        bankAccountNumber: '',
        cryptoAddress:
            (_method == _PayoutMethod.btc || _method == _PayoutMethod.usdc)
                ? _cryptoAddressController.text
                : '',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.payoutRequestSubmitted)),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bitcoinTitle = CryptoPayoutText.bitcoinTitle(context);
    final usdcPolygonTitle = CryptoPayoutText.usdcPolygonTitle(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestPayoutTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: AppTheme.outline.withOpacity(0.65)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.payoutRules,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _RuleLine(
                      icon: Icons.flag_circle_outlined,
                        text: l10n.minimumPayoutIs(
                          '${FirestoreService.minimumPayoutCoins}',
                        ),
                    ),
                    _RuleLine(
                      icon: Icons.schedule_outlined,
                        text: l10n.processingCanTake(
                          '${FirestoreService.payoutProcessingDays}',
                        ),
                    ),
                    _RuleLine(
                      icon: Icons.verified_user_outlined,
                      text: l10n.everyRequestReviewed,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.submitUsingBalance,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.estimatedEarningsNotGuaranteed,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text(
                l10n.payoutMethod,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_PayoutMethod>(
                  segments: [
                    ButtonSegment(
                      value: _PayoutMethod.paypal,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('PayPal'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.revolut,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('Revolut'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.btc,
                      icon: const Icon(Icons.currency_bitcoin_rounded),
                      label: Text(bitcoinTitle),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.usdc,
                      icon: const Icon(Icons.token_rounded),
                      label: Text(usdcPolygonTitle),
                    ),
                  ],
                  selected: {_method},
                  onSelectionChanged: (value) {
                    setState(() => _method = value.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.resolveWith((states) {
                      if (states.contains(MaterialState.selected)) {
                        return AppTheme.primary.withOpacity(0.12);
                      }
                      return Theme.of(context).colorScheme.surface;
                    }),
                    side: MaterialStateProperty.all(
                      BorderSide(color: AppTheme.outline.withOpacity(0.65)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_method != _PayoutMethod.btc && _method != _PayoutMethod.usdc) ...[
                Text(
                  l10n.payoutCurrency,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_PayoutCurrency>(
                    segments: const [
                      ButtonSegment(
                        value: _PayoutCurrency.eur,
                        label: Text('EUR'),
                      ),
                      ButtonSegment(
                        value: _PayoutCurrency.gbp,
                        label: Text('GBP'),
                      ),
                      ButtonSegment(
                        value: _PayoutCurrency.usd,
                        label: Text('USD'),
                      ),
                    ],
                    selected: {_currency},
                    onSelectionChanged: (value) {
                      setState(() => _currency = value.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith((states) {
                        if (states.contains(MaterialState.selected)) {
                          return AppTheme.primary.withOpacity(0.12);
                        }
                        return Theme.of(context).colorScheme.surface;
                      }),
                      side: MaterialStateProperty.all(
                        BorderSide(color: AppTheme.outline.withOpacity(0.65)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _viewsController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: false,
                  signed: false,
                ),
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: l10n.viewsToRequest,
                  helperText: l10n.minimumViewsHelper,
                ),
                onChanged: (value) {
                  final normalized = _normalizedViewsInput(value);
                  if (normalized == value) return;
                  _viewsController.value = TextEditingValue(
                    text: normalized,
                    selection: TextSelection.collapsed(
                      offset: normalized.length,
                    ),
                  );
                },
                validator: (value) {
                  final normalized = _normalizedViewsInput(value);
                  if (normalized.isEmpty) {
                    return l10n.enterAmount;
                  }

                  final number = int.tryParse(normalized);
                  if (number == null || number <= 0) {
                    return l10n.enterValidPositiveNumber;
                  }
                  if (number < FirestoreService.minimumPayoutCoins) {
                    return l10n.minimumPayoutIs(
                      '${FirestoreService.minimumPayoutCoins}',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountHolderController,
                decoration: InputDecoration(
                  labelText: l10n.accountHolderName,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterAccountHolderName;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_method == _PayoutMethod.paypal) ...[
                TextFormField(
                  controller: _payPalController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: l10n.paypalEmail,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.enterPaypalEmail;
                    }
                    if (!trimmed.contains('@')) {
                      return l10n.enterValidPaypalEmail;
                    }
                    return null;
                  },
                ),
              ] else if (_method == _PayoutMethod.revolut) ...[
                TextFormField(
                  controller: _revolutController,
                  decoration: InputDecoration(
                    labelText: l10n.revolutUsername,
                    helperText: l10n.revolutExample,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.enterRevolutUsername;
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _cryptoAddressController,
                  decoration: InputDecoration(
                    labelText: _method == _PayoutMethod.btc
                        ? CryptoPayoutText.bitcoinAddressLabel(context)
                        : CryptoPayoutText.usdcPolygonAddressLabel(context),
                    helperText: _method == _PayoutMethod.btc
                        ? CryptoPayoutText.pasteBitcoinAddress(context)
                        : CryptoPayoutText.pasteUsdcPolygonAddress(context),
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return _method == _PayoutMethod.btc
                          ? CryptoPayoutText.enterBitcoinAddress(context)
                          : CryptoPayoutText.enterUsdcPolygonAddress(context);
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting ? l10n.sending : l10n.submitRequest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primarySoft, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
