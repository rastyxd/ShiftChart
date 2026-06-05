import 'package:flutter/material.dart';

enum InAppNotificationType {
  success,
  error,
  warning,
  info,
  medication,
}

class InAppNotification {
  final String id;
  final String title;
  final String message;
  final InAppNotificationType type;
  final DateTime timestamp;
  final VoidCallback? onTap;
  final Duration duration;
  final bool isRead;
  final Map<String, dynamic>? data;

  InAppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.type = InAppNotificationType.info,
    DateTime? timestamp,
    this.onTap,
    this.duration = const Duration(seconds: 4),
    this.isRead = false,
    this.data,
  }) : timestamp = timestamp ?? DateTime.now();

  InAppNotification copyWith({
    String? id,
    String? title,
    String? message,
    InAppNotificationType? type,
    DateTime? timestamp,
    VoidCallback? onTap,
    Duration? duration,
    bool? isRead,
    Map<String, dynamic>? data,
  }) {
    return InAppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      onTap: onTap ?? this.onTap,
      duration: duration ?? this.duration,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
    );
  }

  Color getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (type) {
      case InAppNotificationType.success:
        return Colors.green;
      case InAppNotificationType.error:
        return colorScheme.error;
      case InAppNotificationType.warning:
        return Colors.orange;
      case InAppNotificationType.info:
        return colorScheme.primary;
      case InAppNotificationType.medication:
        return colorScheme.secondary;
    }
  }

  IconData get icon {
    switch (type) {
      case InAppNotificationType.success:
        return Icons.check_circle;
      case InAppNotificationType.error:
        return Icons.error;
      case InAppNotificationType.warning:
        return Icons.warning;
      case InAppNotificationType.info:
        return Icons.info;
      case InAppNotificationType.medication:
        return Icons.medication;
    }
  }
}
