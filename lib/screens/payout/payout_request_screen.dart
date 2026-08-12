import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

enum _PayoutMethod { paypal, revolut, bank, btc, usdc }
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
      'bank' => _PayoutMethod.bank,
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

  Future<void> _submit() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.createPayoutRequest(
        uid: user.uid,
        coinsRequested: int.parse(_viewsController.text.trim()),
        payoutMethod: switch (_method) {
          _PayoutMethod.paypal => 'paypal',
          _PayoutMethod.revolut => 'revolut',
          _PayoutMethod.bank => 'bank',
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
        bankName: _method == _PayoutMethod.bank ? _bankNameController.text : '',
        iban: _method == _PayoutMethod.bank ? _ibanController.text : '',
        bankAccountNumber:
            _method == _PayoutMethod.bank ? _bankAccountNumberController.text : '',
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
    final isDutch = Localizations.localeOf(context).languageCode.toLowerCase() == 'nl';
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
                      text: isDutch
                          ? 'Minimale uitbetaling: ${FirestoreService.minimumPayoutCoins} ads.'
                          : 'Minimum payout: ${FirestoreService.minimumPayoutCoins} ads.',
                    ),
                    _RuleLine(
                      icon: Icons.schedule_outlined,
                      text: isDutch
                          ? 'Verwerking kan tot ${FirestoreService.payoutProcessingDays} uur duren na admin-goedkeuring.'
                          : 'Processing can take up to ${FirestoreService.payoutProcessingDays} hours after admin approval.',
                    ),
                    _RuleLine(
                      icon: Icons.verified_user_outlined,
                      text: l10n.everyRequestReviewed,
                    ),
                    _RuleLine(
                      icon: Icons.account_balance_outlined,
                      text: l10n.useBankAddIban,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isDutch
                    ? 'Dien een uitbetalingsaanvraag in met je adsaldo.'
                    : 'Submit a payout request using your ad balance.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isDutch
                    ? 'Alleen een schatting. 1 ad ≈ €0,001 en de werkelijke opbrengst kan afwijken.'
                    : 'Estimate only. 1 ad ≈ €0.001 and actual earnings may vary.',
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
                  segments: const [
                    ButtonSegment(
                      value: _PayoutMethod.paypal,
                      icon: Icon(Icons.payments_outlined),
                      label: Text('PayPal'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.revolut,
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      label: Text('Revolut'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.bank,
                      icon: Icon(Icons.account_balance_outlined),
                      label: Text('Bank'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.btc,
                      icon: Icon(Icons.currency_bitcoin_rounded),
                      label: Text('BTC'),
                    ),
                    ButtonSegment(
                      value: _PayoutMethod.usdc,
                      icon: Icon(Icons.token_rounded),
                      label: Text('USDC'),
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
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: isDutch ? 'Ads aanvragen' : 'Ads to request',
                  helperText: isDutch ? 'Minimaal 1.000 ads' : 'Minimum 1,000 ads',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.enterAmount;
                  }

                  final number = int.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return l10n.enterValidPositiveNumber;
                  }
                  if (number < FirestoreService.minimumPayoutCoins) {
                    return isDutch
                        ? 'Minimale uitbetaling is ${FirestoreService.minimumPayoutCoins} ads.'
                        : 'Minimum payout is ${FirestoreService.minimumPayoutCoins} ads.';
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
              ] else if (_method == _PayoutMethod.bank) ...[
                TextFormField(
                  controller: _bankNameController,
                  decoration: InputDecoration(
                    labelText: l10n.bankName,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.enterBankName;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ibanController,
                  decoration: InputDecoration(
                    labelText: l10n.iban,
                    helperText: l10n.ibanOptional,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankAccountNumberController,
                  decoration: InputDecoration(
                    labelText: l10n.bankAccountNumber,
                    helperText: l10n.bankRequiredIfNoIban,
                  ),
                  validator: (value) {
                    final iban = _ibanController.text.trim();
                    final accountNumber = value?.trim() ?? '';
                    if (iban.isEmpty && accountNumber.isEmpty) {
                      return l10n.enterIbanOrBank;
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _cryptoAddressController,
                  decoration: InputDecoration(
                    labelText: '${_method == _PayoutMethod.btc ? 'BTC' : 'USDC'} ${l10n.walletAddress}',
                    helperText: l10n.pasteWalletAddress,
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return l10n.enterWalletAddress;
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
