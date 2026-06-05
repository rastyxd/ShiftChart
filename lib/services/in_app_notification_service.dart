import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shiftchart/models/in_app_notification.dart';
import 'package:shiftchart/theme/AppColors.dart';

/// Service for managing in-app notifications (banners/overlays within the app)
class InAppNotificationService {
  static final InAppNotificationService _instance = InAppNotificationService._internal();
  factory InAppNotificationService() => _instance;
  InAppNotificationService._internal();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  OverlayEntry? _currentOverlay;
  Timer? _dismissTimer;

  // Stream controller for notification history
  final StreamController<List<InAppNotification>> _notificationsController =
      StreamController<List<InAppNotification>>.broadcast();

  final List<InAppNotification> _notifications = [];

  Stream<List<InAppNotification>> get notificationsStream => _notificationsController.stream;
  List<InAppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Show a notification banner overlay
  void show(InAppNotification notification) {
    _notifications.insert(0, notification);
    _notificationsController.add(_notifications);

    _showOverlay(notification);
  }

  /// Show success notification
  void showSuccess({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    show(InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: InAppNotificationType.success,
      onTap: onTap,
    ));
  }

  /// Show error notification
  void showError({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    show(InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: InAppNotificationType.error,
      onTap: onTap,
      duration: const Duration(seconds: 6),
    ));
  }

  /// Show warning notification
  void showWarning({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    show(InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: InAppNotificationType.warning,
      onTap: onTap,
    ));
  }

  /// Show info notification
  void showInfo({
    required String title,
    required String message,
    VoidCallback? onTap,
  }) {
    show(InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      type: InAppNotificationType.info,
      onTap: onTap,
    ));
  }

  /// Show medication reminder notification
  void showMedicationReminder({
    required String medicationName,
    required String patientName,
    required String dose,
    VoidCallback? onTap,
  }) {
    show(InAppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Medication Due: $medicationName',
      message: 'Patient: $patientName - Dose: $dose',
      type: InAppNotificationType.medication,
      onTap: onTap,
      duration: const Duration(seconds: 8),
    ));
  }

  void _showOverlay(InAppNotification notification) {
    // Dismiss any existing overlay
    dismiss();

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _currentOverlay = OverlayEntry(
      builder: (context) => _InAppNotificationOverlay(
        notification: notification,
        onDismiss: dismiss,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss after duration
    _dismissTimer = Timer(notification.duration, dismiss);
  }

  /// Dismiss current notification overlay
  void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// Mark notification as read
  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _notificationsController.add(_notifications);
    }
  }

  /// Mark all notifications as read
  void markAllAsRead() {
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _notificationsController.add(_notifications);
  }

  /// Clear all notifications
  void clearAll() {
    _notifications.clear();
    _notificationsController.add(_notifications);
  }

  /// Clear a specific notification
  void clear(String id) {
    _notifications.removeWhere((n) => n.id == id);
    _notificationsController.add(_notifications);
  }

  void dispose() {
    dismiss();
    _notificationsController.close();
  }
}

class _InAppNotificationOverlay extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;

  const _InAppNotificationOverlay({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationOverlay> createState() => _InAppNotificationOverlayState();
}

class _InAppNotificationOverlayState extends State<_InAppNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.normal,
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notification = widget.notification;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                notification.onTap?.call();
                _handleDismiss();
              },
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta! < -10) {
                  _handleDismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: notification.getColor(context).withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: notification.getColor(context).withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: notification.getColor(context).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        notification.icon,
                        color: notification.getColor(context),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            notification.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _handleDismiss,
                      icon: Icon(
                        Icons.close,
                        size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
