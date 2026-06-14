import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../payout/payout_request_screen.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firestoreService = FirestoreService();

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<AppUser?>(
            stream: firestoreService.watchUser(user.uid),
            builder: (context, snapshot) {
              final appUser = snapshot.data;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available balance',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${appUser?.coins ?? 0} coins',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PayoutRequestScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.request_quote),
                        label: const Text('Request Payout'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Payout history',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<PayoutRequest>>(
            stream: firestoreService.watchPayouts(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final payouts = snapshot.data ?? const <PayoutRequest>[];
              if (payouts.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No payout requests yet.'),
                  ),
                );
              }

              return Column(
                children: payouts.map((payout) {
                  final formattedDate = payout.createdAt == null
                      ? 'Pending timestamp'
                      : DateFormat.yMMMd().add_jm().format(payout.createdAt!);

                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.payments_outlined),
                      ),
                      title: Text('${payout.coinsRequested} coins'),
                      subtitle: Text(
                        'Status: ${payout.status}\nCreated: $formattedDate',
                      ),
                    ),
                  );
                }).toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}
