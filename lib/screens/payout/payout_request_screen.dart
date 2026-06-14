import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class PayoutRequestScreen extends StatefulWidget {
  const PayoutRequestScreen({super.key});

  @override
  State<PayoutRequestScreen> createState() => _PayoutRequestScreenState();
}

class _PayoutRequestScreenState extends State<PayoutRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _coinsController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _coinsController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Submit a payout request using your coin balance.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Coins to request',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter an amount.';
                  }

                  final number = int.tryParse(value.trim());
                  if (number == null || number <= 0) {
                    return 'Enter a valid positive number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
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
