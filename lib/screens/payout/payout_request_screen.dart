import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _coinsController = TextEditingController();
  final _payPalController = TextEditingController();
  final _ibanController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _coinsController.dispose();
    _payPalController.dispose();
    _ibanController.dispose();
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
        coinsRequested: int.parse(_coinsController.text.trim()),
        payPalEmail: _payPalController.text,
        ibanOrBankAccount: _ibanController.text,
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
                          'Minimum payout is ${FirestoreService.minimumPayoutCoins} coins.',
                    ),
                    _RuleLine(
                      icon: Icons.schedule_outlined,
                      text:
                          'Processing can take up to ${FirestoreService.payoutProcessingDays} days after admin approval.',
                    ),
                    const _RuleLine(
                      icon: Icons.account_balance_outlined,
                      text:
                          'Add an account holder name and at least one payout destination.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Submit a payout request using your coin balance.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Coins to request',
                  helperText: 'Minimum 10,000 coins',
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
                    return 'Minimum payout is ${FirestoreService.minimumPayoutCoins} coins.';
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
              TextFormField(
                controller: _payPalController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'PayPal email',
                  helperText: 'Optional if you provide IBAN / bank account',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isNotEmpty && !trimmed.contains('@')) {
                    return 'Enter a valid PayPal email.';
                  }
                  if (trimmed.isEmpty && _ibanController.text.trim().isEmpty) {
                    return 'Enter a PayPal email or an IBAN / bank account.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ibanController,
                decoration: const InputDecoration(
                  labelText: 'IBAN / bank account',
                  helperText: 'Optional if you provide PayPal email',
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty && _payPalController.text.trim().isEmpty) {
                    return 'Enter an IBAN / bank account or a PayPal email.';
                  }
                  return null;
                },
              ),
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
