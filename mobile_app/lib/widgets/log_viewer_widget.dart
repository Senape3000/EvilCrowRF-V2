import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import '../providers/log_provider.dart';
import '../models/log_entry.dart';

class LogViewerWidget extends StatelessWidget {
  const LogViewerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogProvider>(
      builder: (context, logProvider, child) {
        final logs = logProvider.logs;

        if (logs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.noLogsYet,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)!.commandsAndResponsesWillAppearHere,
                  style: const TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Header with controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.logsCount(logs.length),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => logProvider.clearLogs(),
                    icon: const Icon(Icons.clear_all),
                    tooltip: AppLocalizations.of(context)!.clearAllLogs,
                  ),
                ],
              ),
            ),
            
            // Logs list
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildLogItem(context, log);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogItem(BuildContext context, LogEntry log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          left: BorderSide(
            color: log.levelColor,
            width: 4,
          ),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                log.levelIcon,
                size: 16,
                color: log.levelColor,
              ),
              const SizedBox(width: 8),
              Text(
                log.levelName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: log.levelColor,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                log.formattedTime,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            log.message,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          if (log.details != null) ...[
            const SizedBox(height: 4),
            Text(
              log.details!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
