import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/hive_models.dart';
import '../services/crawl_log_service.dart';
import '../services/source_settings_service.dart';

/// Shows a history of sources that failed to load during a crawl (timeouts,
/// network or parse errors), so problems with a specific news source are
/// easy to spot without digging through debug console output. Each failure
/// can also be turned off right from here, so a consistently bad source
/// doesn't need a trip to the Sources screen to get rid of.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _logService = CrawlLogService();
  final _sourceSettingsService = SourceSettingsService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Source Logs',
          style: GoogleFonts.lexend(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white70),
            tooltip: 'Clear logs',
            onPressed: () => _confirmClear(context),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Same background as the rest of the app
          Positioned.fill(
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

          // 2. Live log list
          Positioned.fill(
            child: SafeArea(
              child: StreamBuilder<List<CrawlLogHive>>(
                stream: _logService.watchLogs(),
                initialData: _logService.getLogs(),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? const [];

                  if (logs.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    itemCount: logs.length,
                    itemBuilder: (context, index) =>
                        _buildLogTile(logs[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent.withValues(alpha: 0.7),
              size: 56,
            ),
            const SizedBox(height: 16),
            Text(
              'No failures logged',
              style: GoogleFonts.lexend(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sources that time out or fail to load will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogTile(CrawlLogHive entry) {
    final isTimeout = entry.status.toLowerCase() == 'timeout';
    final accent = isTimeout ? const Color(0xFFFBBF24) : const Color(0xFFF87171);
    final icon = isTimeout ? Icons.timer_off_outlined : Icons.error_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 18),
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
                              entry.sourceName,
                              style: GoogleFonts.lexend(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeago.format(entry.timestamp),
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.status,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.message,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildDisableAction(entry.sourceName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Lets the user turn this source off right from its failure log, instead
  /// of having to go find it in the Sources screen.
  Widget _buildDisableAction(String domain) {
    final isEnabled = _sourceSettingsService.isEnabled(domain);

    if (!isEnabled) {
      return const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.block, size: 14, color: Colors.white38),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Source disabled — won\'t be loaded next refresh',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => _disableSource(domain),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          minimumSize: const Size(0, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: const Color(0xFFF87171),
        ),
        icon: const Icon(Icons.block, size: 16),
        label: const Text(
          'Disable this source',
          style: TextStyle(fontSize: 12),
        ),
      ),
    );
  }

  Future<void> _disableSource(String domain) async {
    await _sourceSettingsService.setEnabled(domain, false);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$domain disabled — it will be skipped next refresh'),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        title: const Text('Clear logs?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently remove all logged source failures.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logService.clear();
    }
  }
}
