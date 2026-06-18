import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

enum _PayoutMethod { paypal, revolut }

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
  final _firestoreService = FirestoreService();

  bool _isSubmitting = false;
  late _PayoutMethod _method;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialMethod ?? '').toLowerCase();
    _method = initial == 'revolut' ? _PayoutMethod.revolut : _PayoutMethod.paypal;
  }

  @override
  void dispose() {
    _viewsController.dispose();
    _payPalController.dispose();
    _revolutController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    try {
      await _firestoreService.createPayoutRequest(
        uid: user.uid,
        coinsRequested: int.parse(_viewsController.text.trim()),
        payoutMethod: _method == _PayoutMethod.paypal ? 'paypal' : 'revolut',
        payPalEmail: _method == _PayoutMethod.paypal ? _payPalController.text : '',
        revolutUsername:
            _method == _PayoutMethod.revolut ? _revolutController.text : '',
        accountHolderName: _accountHolderController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request submitted.')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Request Payout')),
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
                      'Payout rules',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _RuleLine(
                      icon: Icons.flag_circle_outlined,
                      text:
                          'Minimum payout is ${FirestoreService.minimumPayoutCoins} views.',
                    ),
                    _RuleLine(
                      icon: Icons.schedule_outlined,
                      text:
                          'Processing can take up to ${FirestoreService.payoutProcessingDays} days after admin approval.',
                    ),
                    const _RuleLine(
                      icon: Icons.verified_user_outlined,
                      text: 'Every request is reviewed by admin before it is paid.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Submit a payout request using your view balance.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated earnings only. 50 completed views ≈ €0.01 and this is not a guaranteed payout promise.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text(
                'Payout method',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              SegmentedButton<_PayoutMethod>(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _viewsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Views to request',
                  helperText: 'Minimum 10,000 views',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an amount.';
                  }

                  final number = int.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return 'Enter a valid positive number.';
                  }
                  if (number < FirestoreService.minimumPayoutCoins) {
                    return 'Minimum payout is ${FirestoreService.minimumPayoutCoins} views.';
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
              const SizedBox(height: 16),
              if (_method == _PayoutMethod.paypal) ...[
                TextFormField(
                  controller: _payPalController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'PayPal email',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Enter a PayPal email.';
                    }
                    if (!trimmed.contains('@')) {
                      return 'Enter a valid PayPal email.';
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _revolutController,
                  decoration: const InputDecoration(
                    labelText: 'Revolut username',
                    helperText: 'Example: @yourname',
                  ),
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return 'Enter your Revolut username.';
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
                    _isSubmitting ? 'Submitting...' : 'Submit Request',
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
