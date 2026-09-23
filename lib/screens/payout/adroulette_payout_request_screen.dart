import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/payout_i18n.dart';

enum _AdroulettePayoutMethod { paypal, revolut, btc, usdc }
enum _AdroulettePayoutCurrency { eur, gbp, usd }

class AdroulettePayoutRequestScreen extends StatefulWidget {
  const AdroulettePayoutRequestScreen({super.key});

  @override
  State<AdroulettePayoutRequestScreen> createState() =>
      _AdroulettePayoutRequestScreenState();
}

class _AdroulettePayoutRequestScreenState
    extends State<AdroulettePayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adsController = TextEditingController();
  final _payPalController = TextEditingController();
  final _revolutController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _cryptoAddressController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isSubmitting = false;
  _AdroulettePayoutMethod _method = _AdroulettePayoutMethod.paypal;
  _AdroulettePayoutCurrency _currency = _AdroulettePayoutCurrency.eur;

  @override
  void dispose() {
    _adsController.dispose();
    _payPalController.dispose();
    _revolutController.dispose();
    _accountHolderController.dispose();
    _cryptoAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitAdroulettePayout() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versionName = packageInfo.version.trim();
      final buildNumber = int.tryParse(packageInfo.buildNumber.trim()) ?? 0;
      final appVersion = '$versionName+${packageInfo.buildNumber.trim()}';

      if (!FirestoreService.isPayoutBuildAllowed(buildNumber)) {
        throw Exception(
          PayoutI18n.updateRequiredMessage(
            context,
            FirestoreService.minimumPayoutVersion,
          ),
        );
      }

      await _firestoreService.createAdroulettePayoutRequest(
        uid: user.uid,
        adsRequested: int.parse(_adsController.text.trim()),
        appVersion: appVersion,
        versionName: versionName,
        buildNumber: buildNumber,
        payoutMethod: switch (_method) {
          _AdroulettePayoutMethod.paypal => 'paypal',
          _AdroulettePayoutMethod.revolut => 'revolut',
          _AdroulettePayoutMethod.btc => 'btc',
          _AdroulettePayoutMethod.usdc => 'usdc',
        },
        payPalEmail:
            _method == _AdroulettePayoutMethod.paypal ? _payPalController.text : '',
        revolutUsername: _method == _AdroulettePayoutMethod.revolut
            ? _revolutController.text
            : '',
        accountHolderName: _accountHolderController.text,
        payoutCurrency: switch (_method) {
          _AdroulettePayoutMethod.btc => 'BTC',
          _AdroulettePayoutMethod.usdc => 'USDC',
          _ => _currency.name.toUpperCase(),
        },
        cryptoAddress:
            (_method == _AdroulettePayoutMethod.btc ||
                    _method == _AdroulettePayoutMethod.usdc)
                ? _cryptoAddressController.text
                : '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adroulette payout request submitted.')),
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
    final minimumAds = FirestoreService.minimumAdRoulettePayoutAds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Adroulette payout'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: const Color(0xFF3A2C00).withOpacity(0.92),
                  border: Border.all(
                    color: const Color(0xFFE6C54A).withOpacity(0.55),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adroulette payout only',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This page only uses your Adroulette ads balance. It does not use your normal VideoMoney ads.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Minimum request: $minimumAds Adroulette ads.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFFFFE082),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Payout method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_AdroulettePayoutMethod>(
                  segments: const [
                    ButtonSegment(
                      value: _AdroulettePayoutMethod.paypal,
                      icon: Icon(Icons.payments_outlined),
                      label: Text('PayPal'),
                    ),
                    ButtonSegment(
                      value: _AdroulettePayoutMethod.revolut,
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      label: Text('Revolut'),
                    ),
                    ButtonSegment(
                      value: _AdroulettePayoutMethod.btc,
                      icon: Icon(Icons.currency_bitcoin_rounded),
                      label: Text('BTC'),
                    ),
                    ButtonSegment(
                      value: _AdroulettePayoutMethod.usdc,
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
                        return const Color(0xFFE6C54A).withOpacity(0.16);
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
              if (_method != _AdroulettePayoutMethod.btc &&
                  _method != _AdroulettePayoutMethod.usdc) ...[
                Text(
                  'Payout currency',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<_AdroulettePayoutCurrency>(
                    segments: const [
                      ButtonSegment(
                        value: _AdroulettePayoutCurrency.eur,
                        label: Text('EUR'),
                      ),
                      ButtonSegment(
                        value: _AdroulettePayoutCurrency.gbp,
                        label: Text('GBP'),
                      ),
                      ButtonSegment(
                        value: _AdroulettePayoutCurrency.usd,
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
                          return const Color(0xFFE6C54A).withOpacity(0.16);
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
                controller: _adsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Adroulette ads to request',
                  helperText: 'Use your Adroulette balance only',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an ads amount.';
                  }
                  final number = int.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return 'Enter a valid positive number.';
                  }
                  if (number < minimumAds) {
                    return 'Minimum request is $minimumAds Adroulette ads.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              if (_method == _AdroulettePayoutMethod.paypal)
                TextFormField(
                  controller: _payPalController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'PayPal email',
                  ),
                  validator: (value) {
                    if (_method != _AdroulettePayoutMethod.paypal) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your PayPal email.';
                    }
                    return null;
                  },
                ),
              if (_method == _AdroulettePayoutMethod.revolut)
                TextFormField(
                  controller: _revolutController,
                  decoration: const InputDecoration(
                    labelText: 'Revolut username',
                  ),
                  validator: (value) {
                    if (_method != _AdroulettePayoutMethod.revolut) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your Revolut username.';
                    }
                    return null;
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountHolderController,
                decoration: const InputDecoration(
                  labelText: 'Account holder name',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter the account holder name.';
                  }
                  return null;
                },
              ),
              if (_method == _AdroulettePayoutMethod.btc ||
                  _method == _AdroulettePayoutMethod.usdc) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cryptoAddressController,
                  decoration: InputDecoration(
                    labelText: _method == _AdroulettePayoutMethod.btc
                        ? 'BTC wallet address'
                        : 'USDC wallet address',
                  ),
                  validator: (value) {
                    if (_method != _AdroulettePayoutMethod.btc &&
                        _method != _AdroulettePayoutMethod.usdc) {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter your wallet address.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This submit button only sends an Adroulette payout request.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Normal VideoMoney payouts stay on the Wallet page. This page is only for Adroulette.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitAdroulettePayout,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE6C54A),
                    foregroundColor: const Color(0xFF231A00),
                  ),
                  icon: Icon(
                    _isSubmitting
                        ? Icons.hourglass_top_rounded
                        : Icons.payments_outlined,
                  ),
                  label: Text(
                    _isSubmitting
                        ? 'Submitting Adroulette payout...'
                        : 'Submit Adroulette payout',
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
