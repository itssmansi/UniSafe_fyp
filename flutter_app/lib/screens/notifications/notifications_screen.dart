import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/supabase_config.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _supabase = SupabaseConfig.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please sign in to view notifications.';
        });
        return;
      }

      // Fetch citizen id
      final citizenRes = await _supabase
          .from('citizens')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      final citizenId = citizenRes?['id']?.toString();
      if (citizenId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Citizen profile not found.';
        });
        return;
      }

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('citizen_id', citizenId)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load notifications: $e';
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final citizenRes = await _supabase
          .from('citizens')
          .select('id')
          .eq('auth_user_id', user.id)
          .maybeSingle();

      final citizenId = citizenRes?['id']?.toString();
      if (citizenId == null) return;

      await _supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('citizen_id', citizenId);

      await _fetchNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _triggerTestNotification() async {
    await NotificationService.notifyComplaintSubmitted(
      complaintId: 'test-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Dark spot reported near Main Street',
    );
    await _fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Notifications & Alerts',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(Icons.done_all, color: Colors.deepPurple),
              onPressed: _markAllAsRead,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchNotifications,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Test notification helper banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.deepPurple.shade100),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.science_outlined, color: Colors.deepPurple),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Test civic complaint push notifications:',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _triggerTestNotification,
                              icon: const Icon(Icons.notification_add, size: 16),
                              label: const Text('Send Test Alert'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_notifications.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.notifications_off_outlined,
                                  size: 64, color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              const Text(
                                'No notifications yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You will receive updates here whenever you submit a complaint or when an authority changes its status.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._notifications.map((notif) {
                          final title = notif['title']?.toString() ?? 'Alert';
                          final body = notif['body']?.toString() ?? '';
                          final isRead = notif['is_read'] == true;
                          final createdAt = notif['created_at'] != null
                              ? DateTime.tryParse(notif['created_at'].toString())
                              : null;

                          final timeStr = createdAt != null
                              ? DateFormat('dd MMM, hh:mm a').format(createdAt.toLocal())
                              : '';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: isRead ? 0.5 : 2,
                            color: isRead ? Colors.white : Colors.deepPurple.shade50.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isRead ? Colors.grey.shade200 : Colors.deepPurple.shade200,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRead
                                          ? Colors.grey.shade100
                                          : Colors.deepPurple.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isRead ? Icons.notifications_none : Icons.notifications_active,
                                      color: isRead ? Colors.grey.shade600 : Colors.deepPurple,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (!isRead)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Colors.deepPurple,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          body,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade700,
                                            height: 1.3,
                                          ),
                                        ),
                                        if (timeStr.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            timeStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
