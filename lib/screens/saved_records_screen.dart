import 'package:flutter/material.dart';
import 'package:shiftchart/screens/hpr_history_screen.dart';

class SavedRecordsScreen extends StatelessWidget {
  const SavedRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Reusing HPRHistoryScreen with the filter enabled provides exactly what's needed
    return const HPRHistoryScreen(showOnlyBookmarked: true);
  }
}
