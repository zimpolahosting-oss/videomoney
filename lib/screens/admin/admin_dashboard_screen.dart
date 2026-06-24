import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_rating.dart';
import '../../models/app_user.dart';
import '../../models/inbox_message.dart';
import '../../models/payout_request.dart';
import '../../models/support_ticket.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

enum _AdminFilter { pending, approved, paid, rejected, all }
enum _NotificationAudience { all, user }

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _firestoreService = FirestoreService();
  final _notificationTitleController = TextEditingController();
  final _notificationMessageController = TextEditingController();
  _AdminFilter _filter = _AdminFilter.pending;
  _NotificationAudience _notificationAudience = _NotificationAudience.all;
  String _selectedNotificationType = 'announcement';
  String? _selectedNotificationUserId;
  bool _isSendingNotification = false;

  @override
  void dispose() {
    _notificationTitleController.dispose();
    _notificationMessageController.dispose();
    super.dispose();
  }

  String _filterToStatus(_AdminFilter filter) {
    return switch (filter) {
      _AdminFilter.pending => 'pending',
      _AdminFilter.approved => 'approved',
      _AdminFilter.paid => 'paid',
      _AdminFilter.rejected => 'rejected',
      _AdminFilter.all => 'all',
    };
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Pending timestamp';
    return DateFormat.yMMMd().add_jm().format(dateTime);
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

  Future<void> _openTicketReplyDialog(
    BuildContext context,
    SupportTicket ticket,
    User adminUser,
  ) async {
    final replyController = TextEditingController(text: ticket.latestReply);
    var selectedStatus = ticket.status;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.subject,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: FirestoreService.allowedSupportStatuses
                        .map(
                          (status) => DropdownMenuItem<String>(
                            value: status,
                            child: Text(status.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() => selectedStatus = value);
                    },
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: replyController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Reply',
                      hintText: 'Type your reply for the user',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        try {
                          await _firestoreService.replyToSupportTicket(
                            ticketId: ticket.id,
                            status: selectedStatus,
                            replyMessage: replyController.text,
                            adminUserId: adminUser.uid,
                            adminEmail: adminUser.email ?? '',
                          );
                          if (!mounted) return;
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Reply sent to the user inbox.'),
                            ),
                          );
                        } catch (error) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.toString().replaceFirst('Exception: ', ''),
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Send reply'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    replyController.dispose();
  }

  Future<void> _showUserHistorySheet(
    BuildContext context,
    AppUser appUser,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return StreamBuilder<List<SupportTicket>>(
              stream: _firestoreService.watchSupportTicketsForUser(appUser.uid),
              builder: (context, snapshot) {
                final tickets = snapshot.data ?? const <SupportTicket>[];
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    Text(
                      appUser.email,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Views: ${NumberFormat.decimalPattern().format(appUser.views)} • Videos: ${NumberFormat.decimalPattern().format(appUser.videosWatched)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Support history',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (tickets.isEmpty)
                      Text(
                        'No support history found for this user.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    else
                      ...tickets.map(
                        (ticket) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(
                              color: AppTheme.outline.withOpacity(0.45),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ticket.subject,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${ticket.type.toUpperCase()} • ${ticket.status.toUpperCase()} • ${_formatDateTime(ticket.updatedAt)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ticket.message,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (ticket.hasReply) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Latest reply: ${ticket.latestReply}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _sendNotification(User adminUser) async {
    setState(() => _isSendingNotification = true);
    try {
      await _firestoreService.createAdminNotification(
        createdByUid: adminUser.uid,
        createdByEmail: adminUser.email ?? '',
        audience:
            _notificationAudience == _NotificationAudience.all ? 'all' : 'user',
        type: _selectedNotificationType,
        title: _notificationTitleController.text,
        message: _notificationMessageController.text,
        targetUserId: _selectedNotificationUserId,
      );
      if (!mounted) return;
      _notificationTitleController.clear();
      _notificationMessageController.clear();
      setState(() {
        _notificationAudience = _NotificationAudience.all;
        _selectedNotificationUserId = null;
        _selectedNotificationType = 'announcement';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification queued for push and inbox delivery.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingNotification = false);
      }
    }
  }

  Widget _buildPayoutsTab() {
    final statusFilter = _filterToStatus(_filter);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
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
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<List<PayoutRequest>>(
          stream: _firestoreService.watchAllPayoutRequests(status: statusFilter),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final payouts = snapshot.data ?? const <PayoutRequest>[];
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
                final method = payout.payoutMethod.isNotEmpty
                    ? payout.payoutMethod
                    : (payout.revolutUsername.isNotEmpty ? 'revolut' : 'paypal');
                final destination = method == 'revolut'
                    ? 'Revolut: ${payout.revolutUsername.isNotEmpty ? payout.revolutUsername : payout.ibanOrBankAccount}'
                    : 'PayPal: ${payout.payPalEmail}';
                final statusLower = payout.status.toLowerCase();
                final canApprove = statusLower == 'pending';
                final canMarkPaid = statusLower == 'approved';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
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
                        payout.userEmail.isNotEmpty ? payout.userEmail : payout.userId,
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
                        _formatDateTime(payout.createdAt),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (canApprove || canMarkPaid) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            if (canApprove) ...[
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _setStatus(payout, 'approved'),
                                  child: const Text('Approve'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFFF7B7B),
                                  ),
                                  onPressed: () => _setStatus(payout, 'rejected'),
                                  child: const Text('Reject'),
                                ),
                              ),
                            ] else if (canMarkPaid)
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => _setStatus(payout, 'paid'),
                                  child: const Text('Mark Paid'),
                                ),
                              ),
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
    );
  }

  Widget _buildTicketsTab(User adminUser) {
    return StreamBuilder<List<SupportTicket>>(
      stream: _firestoreService.watchAllSupportTickets(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final tickets = snapshot.data ?? const <SupportTicket>[];
        if (tickets.isEmpty) {
          return const Center(child: Text('No support tickets found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            final ticket = tickets[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ticket.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _SupportStatusBadge(status: ticket.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${ticket.type.toUpperCase()} • ${ticket.email.isEmpty ? ticket.userId : ticket.email}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ticket.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (ticket.hasReply) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Latest reply: ${ticket.latestReply}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    _formatDateTime(ticket.updatedAt),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              _openTicketReplyDialog(context, ticket, adminUser),
                          child: const Text('Reply'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _firestoreService.updateSupportTicketStatus(
                            ticketId: ticket.id,
                            status: 'closed',
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsTab(User adminUser, List<AppUser> users) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
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
                'Send notification',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SegmentedButton<_NotificationAudience>(
                segments: const [
                  ButtonSegment(
                    value: _NotificationAudience.all,
                    label: Text('All users'),
                  ),
                  ButtonSegment(
                    value: _NotificationAudience.user,
                    label: Text('One user'),
                  ),
                ],
                selected: {_notificationAudience},
                onSelectionChanged: (value) {
                  setState(() => _notificationAudience = value.first);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _selectedNotificationType,
                items: const [
                  DropdownMenuItem(
                    value: 'announcement',
                    child: Text('Announcement'),
                  ),
                  DropdownMenuItem(
                    value: 'bonus',
                    child: Text('Bonus event'),
                  ),
                  DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Maintenance'),
                  ),
                  DropdownMenuItem(
                    value: 'update',
                    child: Text('App update'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedNotificationType = value);
                },
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              if (_notificationAudience == _NotificationAudience.user) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: users.any((user) => user.uid == _selectedNotificationUserId)
                      ? _selectedNotificationUserId
                      : null,
                  items: users
                      .map(
                        (user) => DropdownMenuItem<String>(
                          value: user.uid,
                          child: Text(
                            user.email.isEmpty ? user.uid : user.email,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => _selectedNotificationUserId = value);
                  },
                  decoration: const InputDecoration(labelText: 'User'),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: _notificationTitleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notificationMessageController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isSendingNotification
                      ? null
                      : () => _sendNotification(adminUser),
                  child: Text(
                    _isSendingNotification ? 'Sending...' : 'Send notification',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestoreService.watchAdminNotifications(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? const [];
            return Container(
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
                    'Notification history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  if (docs.isEmpty)
                    Text(
                      'No admin notifications yet.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  else
                    ...docs.take(10).map((doc) {
                      final data = doc.data();
                      final title = data['title'] as String? ?? '';
                      final message = data['message'] as String? ?? '';
                      final status = data['status'] as String? ?? 'pending';
                      final audience = data['audience'] as String? ?? 'all';
                      final createdAt =
                          (data['createdAt'] as Timestamp?)?.toDate();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white.withOpacity(0.03),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              message,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${audience.toUpperCase()} • ${status.toUpperCase()} • ${_formatDateTime(createdAt)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildInboxTab() {
    return StreamBuilder<List<InboxMessage>>(
      stream: _firestoreService.watchAllInboxMessages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data ?? const <InboxMessage>[];
        if (messages.isEmpty) {
          return const Center(child: Text('No inbox messages found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          message.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _SimpleBadge(
                        label: message.read ? 'READ' : 'NEW',
                        color: message.read ? AppTheme.textMuted : AppTheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'User: ${message.userId}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${message.type.toUpperCase()} • ${_formatDateTime(message.createdAt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRatingsTab() {
    return StreamBuilder<List<AppRating>>(
      stream: _firestoreService.watchAllRatings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final ratings = snapshot.data ?? const <AppRating>[];
        final totalStars =
            ratings.fold<int>(0, (sum, rating) => sum + rating.stars);
        final average = ratings.isEmpty ? 0.0 : totalStars / ratings.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: _AdminStatCard(
                    title: 'Average score',
                    value: average.toStringAsFixed(1),
                    subtitle: 'Based on ${ratings.length} ratings',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _AdminStatCard(
                    title: '5-star ratings',
                    value: '${ratings.where((rating) => rating.stars == 5).length}',
                    subtitle: 'Top ratings',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (ratings.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No ratings submitted yet.'),
                ),
              )
            else
              ...ratings.map(
                (rating) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rating.email.isEmpty ? rating.userId : rating.email,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _formatDateTime(rating.updatedAt),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < rating.stars
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: AppTheme.coin,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUsersTab(List<AppUser> users) {
    if (users.isEmpty) {
      return const Center(child: Text('No users found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.email.isEmpty ? user.uid : user.email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (user.isAdmin)
                    const _SimpleBadge(
                      label: 'ADMIN',
                      color: AppTheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Views: ${NumberFormat.decimalPattern().format(user.views)} • Videos: ${NumberFormat.decimalPattern().format(user.videosWatched)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'FCM tokens: ${user.fcmTokens.length} • Email verified: ${user.appVerified ? 'Yes' : 'No'}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(user.createdAt),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showUserHistorySheet(context, user),
                  child: const Text('View support history'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
            body: const Center(child: Text('Admin access required.')),
          );
        }

        return StreamBuilder<List<AppUser>>(
          stream: _firestoreService.watchAllUsers(),
          builder: (context, usersSnapshot) {
            final users = usersSnapshot.data ?? const <AppUser>[];
            return DefaultTabController(
              length: 6,
              child: Scaffold(
                appBar: AppBar(
                  title: const Text('Admin Dashboard'),
                  bottom: const TabBar(
                    isScrollable: true,
                    tabs: [
                      Tab(text: 'Payouts'),
                      Tab(text: 'Tickets'),
                      Tab(text: 'Notifications'),
                      Tab(text: 'Inbox'),
                      Tab(text: 'Ratings'),
                      Tab(text: 'Users'),
                    ],
                  ),
                ),
                body: SafeArea(
                  child: TabBarView(
                    children: [
                      _buildPayoutsTab(),
                      _buildTicketsTab(user),
                      _buildNotificationsTab(user, users),
                      _buildInboxTab(),
                      _buildRatingsTab(),
                      _buildUsersTab(users),
                    ],
                  ),
                ),
              ),
            );
          },
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

class _SupportStatusBadge extends StatelessWidget {
  const _SupportStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.toLowerCase()) {
      'processing' => AppTheme.coin,
      'fixed' => AppTheme.primary,
      'closed' => AppTheme.textMuted,
      _ => AppTheme.primarySoft,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
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

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: AppTheme.outline.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  const _SimpleBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
