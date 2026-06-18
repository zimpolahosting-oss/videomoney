import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_user.dart';
import '../../models/payout_request.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

enum _AdminFilter { pending, approved, paid, rejected, all }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();
  _AdminFilter _filter = _AdminFilter.pending;

  String _filterToStatus(_AdminFilter filter) {
    return switch (filter) {
      _AdminFilter.pending => 'pending',
      _AdminFilter.approved => 'approved',
      _AdminFilter.paid => 'paid',
      _AdminFilter.rejected => 'rejected',
      _AdminFilter.all => 'all',
    };
  }

  Future<void> _setStatus(PayoutRequest payout, String status) async {
    try {
      await _firestoreService.updatePayoutStatus(
        payoutId: payout.id,
        status: status,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated payout to ${status.toUpperCase()}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user session found.')),
      );
    }

    return StreamBuilder<AppUser?>(
      stream: _firestoreService.watchUser(user.uid),
      builder: (context, snapshot) {
        final appUser = snapshot.data;
        final isAdmin = appUser?.isAdmin ?? false;

        if (!isAdmin) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Dashboard')),
            body: const Center(
              child: Text('Admin access required.'),
            ),
          );
        }

        final statusFilter = _filterToStatus(_filter);
        return Scaffold(
          appBar: AppBar(title: const Text('Admin Dashboard')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Center(
                  child: Text(
                    'Admin',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payout requests',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<_AdminFilter>(
                          segments: const [
                            ButtonSegment(
                              value: _AdminFilter.pending,
                              label: Text('Pending'),
                            ),
                            ButtonSegment(
                              value: _AdminFilter.approved,
                              label: Text('Approved'),
                            ),
                            ButtonSegment(
                              value: _AdminFilter.paid,
                              label: Text('Paid'),
                            ),
                            ButtonSegment(
                              value: _AdminFilter.rejected,
                              label: Text('Rejected'),
                            ),
                            ButtonSegment(
                              value: _AdminFilter.all,
                              label: Text('All'),
                            ),
                          ],
                          selected: {_filter},
                          onSelectionChanged: (value) {
                            setState(() => _filter = value.first);
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                MaterialStateProperty.resolveWith((states) {
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
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<PayoutRequest>>(
                  stream:
                      _firestoreService.watchAllPayoutRequests(status: statusFilter),
                  builder: (context, payoutsSnapshot) {
                    if (payoutsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final payouts = payoutsSnapshot.data ?? const <PayoutRequest>[];
                    if (payouts.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('No payout requests found.'),
                        ),
                      );
                    }

                    return Column(
                      children: payouts.map((payout) {
                        final formattedDate = payout.createdAt == null
                            ? 'Pending timestamp'
                            : DateFormat.yMMMd().add_jm().format(payout.createdAt!);
                        final method = payout.payoutMethod.isNotEmpty
                            ? payout.payoutMethod
                            : (payout.revolutUsername.isNotEmpty
                                ? 'revolut'
                                : 'paypal');
                        final destination = method == 'revolut'
                            ? 'Revolut: ${payout.revolutUsername.isNotEmpty ? payout.revolutUsername : payout.ibanOrBankAccount}'
                            : 'PayPal: ${payout.payPalEmail}';
                        final requester = payout.userEmail.isNotEmpty
                            ? payout.userEmail
                            : payout.userId;

                        final statusLower = payout.status.toLowerCase();
                        final canApprove = statusLower == 'pending';
                        final canMarkPaid = statusLower == 'approved';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: Theme.of(context).colorScheme.surface,
                            border:
                                Border.all(color: AppTheme.outline.withOpacity(0.55)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${NumberFormat.decimalPattern().format(payout.viewsRequested)} views',
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ),
                                  _StatusBadge(status: payout.status),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                requester,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                destination,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Account holder: ${payout.accountHolderName.isEmpty ? 'Not provided' : payout.accountHolderName}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formattedDate,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (canApprove || canMarkPaid) ...[
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    if (canApprove) ...[
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () =>
                                              _setStatus(payout, 'approved'),
                                          child: const Text('Approve'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFFF7B7B),
                                            side: BorderSide(
                                              color: const Color(0xFFFF7B7B)
                                                  .withOpacity(0.35),
                                            ),
                                          ),
                                          onPressed: () =>
                                              _setStatus(payout, 'rejected'),
                                          child: const Text('Reject'),
                                        ),
                                      ),
                                    ] else if (canMarkPaid) ...[
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: () => _setStatus(payout, 'paid'),
                                          child: const Text('Mark Paid'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(growable: false),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.toLowerCase();
    final color = switch (normalizedStatus) {
      'approved' => AppTheme.primary,
      'paid' => AppTheme.primarySoft,
      'rejected' => const Color(0xFFFF7B7B),
      _ => AppTheme.coin,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
