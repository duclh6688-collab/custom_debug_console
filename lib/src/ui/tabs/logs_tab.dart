import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../event_bus.dart';
import '../../models.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  final List<LogEvent> _items = <LogEvent>[];
  final TextEditingController _search = TextEditingController();
  LogLevel? _levelFilter;
  StreamSubscription<LogEvent>? _sub;
  final bool _autoScroll = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _levelFilter = LogLevel.request;
    _items.addAll(DebugBus.instance.logsSnapshot);
    _sub = DebugBus.instance.logsStream.listen((e) {
      setState(() => _items.add(e));

      if (_autoScroll) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;

          final maxScroll = _scrollController.position.maxScrollExtent;

          _scrollController.animateTo(
            maxScroll,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter regular logs
    final filteredLogs = _items.where((e) {
      final q = _search.text.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          e.message.toLowerCase().contains(q) ||
          (e.tag ?? '').toLowerCase().contains(q);
      final matchesLevel = _levelFilter == null || e.level == _levelFilter;
      return matchesSearch && matchesLevel;
    }).toList();

    // Combine and sort by time
    final allItems = <LogEvent>[];
    allItems.addAll(filteredLogs);

    // Sort by timestamp (logs have ts, network requests have startTime)
    allItems.sort((a, b) {
      DateTime timeA;
      DateTime timeB;

      timeA = a.ts;

      timeB = b.ts;

      return timeB.compareTo(timeA);
    });

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey[900]!, Colors.grey[850]!],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    filled: true,
                    fillColor: Colors.grey[700],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Colors.white),
                  onChanged: (value) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLevelChip('All', _levelFilter == null,
                              () => setState(() => _levelFilter = null)),
                          _buildLevelChip(
                              'Request',
                              _levelFilter == LogLevel.request,
                              () => setState(
                                  () => _levelFilter = LogLevel.request)),
                          _buildLevelChip(
                              'Response',
                              _levelFilter == LogLevel.response,
                              () => setState(
                                  () => _levelFilter = LogLevel.response)),
                          _buildLevelChip(
                              'Debug',
                              _levelFilter == LogLevel.debug,
                              () => setState(
                                  () => _levelFilter = LogLevel.debug)),
                          _buildLevelChip(
                              'Error',
                              _levelFilter == LogLevel.error,
                              () => setState(
                                  () => _levelFilter = LogLevel.error)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildClearButton(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: allItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No logs available',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8),
                    itemCount: allItems.length,
                    itemBuilder: (context, index) {
                      final item = allItems[index];

                      // Otherwise it's a regular log event
                      final event = item;
                      final isError = event.level == LogLevel.error;

                      Color levelColor = Colors.grey;
                      if (isError) {
                        levelColor = Colors.red;
                      }

                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 2),
                        color: Colors.grey[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                              color: levelColor.withValues(alpha: 0.3),
                              width: 1),
                        ),
                        child: ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: levelColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isError
                                  ? Icons.error_outline
                                  : Icons.info_outline,
                              color: levelColor,
                              size: 18,
                            ),
                          ),
                          title: Row(
                            children: [
                              if (event.tag != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[700],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    event.tag!,
                                    style: TextStyle(
                                        color: Colors.grey[300], fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  event.message.split('\n').first,
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 3,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            _formatTimestamp(event.ts),
                            style: TextStyle(
                                color: Colors.grey[400], fontSize: 11),
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration:
                                  BoxDecoration(color: Colors.grey[850]),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Enhanced Copy Row
                                  _buildLogCopyRow(event),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: SelectableText(
                                      event.message,
                                      style: TextStyle(
                                        color: Colors.grey[200],
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelChip(String label, bool selected, VoidCallback onTap) {
    Color color = _getLevelColor(label);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border:
              Border.all(color: selected ? color : Colors.grey[600]!, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[300],
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'debug':
        return Colors.blue;
      case 'request':
        return Colors.green;
      case 'response':
        return Colors.cyan;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime ts) {
    final timeString =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}:${ts.second.toString().padLeft(2, '0')}';
    return timeString;
  }

  Widget _buildLogCopyRow(LogEvent event) {
    Color levelColor;
    switch (event.level) {
      case LogLevel.error:
        levelColor = Colors.red[300]!;
        break;

      case LogLevel.debug:
        levelColor = Colors.grey[400]!;
        break;
      case LogLevel.request:
        levelColor = Colors.orange[400]!;
        break;
      case LogLevel.response:
        levelColor = Colors.brown[400]!;
        break;
    }

    return Column(
      children: [
        // Level and timestamp info
        Row(
          children: [
            Text(
              'Level: ${event.level.name.toUpperCase()}',
              style: TextStyle(
                  color: levelColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              _formatTimestamp(event.ts),
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Copy buttons row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Copy log message only
            ElevatedButton.icon(
              onPressed: () => _copyToClipboard(event.message, 'Log message'),
              icon: Icon(Icons.copy, size: 14),
              label: Text('Copy Message', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size(0, 32),
              ),
            ),

            // Copy full log details (with timestamp, level, tag)
            ElevatedButton.icon(
              onPressed: () => _copyFullLogDetails(event),
              icon: Icon(Icons.info_outline, size: 14),
              label: Text('Copy Full', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size(0, 32),
              ),
            ),

            // Copy as formatted text for sharing
            if (event.tag != null)
              ElevatedButton.icon(
                onPressed: () => _copyFormattedLog(event),
                icon: Icon(Icons.share, size: 14),
                label: Text('Share Format', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size(0, 32),
                ),
              ),
          ],
        ),
      ],
    );
  }

  void _copyFullLogDetails(LogEvent event) {
    StringBuffer fullLog = StringBuffer();

    fullLog.writeln('Timestamp: ${event.ts.toIso8601String()}');
    fullLog.writeln('Level: ${event.level.name.toUpperCase()}');

    if (event.tag != null && event.tag!.isNotEmpty) {
      fullLog.writeln('Tag: ${event.tag}');
    }

    fullLog.writeln('Message:');
    fullLog.write(event.message);

    _copyToClipboard(fullLog.toString(), 'Full log details');
  }

  void _copyFormattedLog(LogEvent event) {
    final timestamp = _formatTimestamp(event.ts);
    final level = event.level.name.toUpperCase();
    final tag = event.tag ?? 'LOG';

    final formatted = '[$timestamp] [$level] [$tag] ${event.message}';
    _copyToClipboard(formatted, 'Formatted log');
  }

  void _copyToClipboard(String text, [String? label]) {
    if (text.trim().isEmpty) {
      _showSnackBar('Nothing to copy', isError: true);
      return;
    }

    Clipboard.setData(ClipboardData(text: text)).then((_) {
      _showSnackBar('${label ?? 'Content'} copied to clipboard');
    }).catchError((error) {
      _showSnackBar('Failed to copy to clipboard', isError: true);
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    final overlay = Overlay.of(context);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _ToastOverlay(
          message: message,
          isError: isError,
          onDismiss: () {
            if (overlayEntry.mounted) {
              overlayEntry.remove();
            }
          },
        );
      },
    );

    overlay.insert(overlayEntry);
  }

  Widget _buildClearButton() {
    final String label = _levelFilter == null
        ? 'Clear All'
        : 'Clear ${_levelFilter!.name.toUpperCase()}';

    return SizedBox(
      height: 30,
      child: ElevatedButton.icon(
        onPressed: _items.isEmpty ? null : _clearLogsByCurrentTab,
        icon: const Icon(Icons.delete_outline, size: 12),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[700],
          disabledForegroundColor: Colors.grey[400],
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        ),
      ),
    );
  }

  void _clearLogsByCurrentTab() {
    final LogLevel? level = _levelFilter;
    final int before = _items.length;

    setState(() {
      if (level == null) {
        _items.clear();
      } else {
        _items.removeWhere((e) => e.level == level);
      }
    });

    // Best-effort: keep DebugBus snapshot aligned.
    DebugBus.instance.clearLogs(level: level);

    final int removed = before - _items.length;
    _showSnackBar(
      removed <= 0
          ? 'Nothing to clear'
          : (level == null
              ? 'Cleared $removed logs'
              : 'Cleared $removed ${level.name.toUpperCase()} logs'),
    );
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _ToastOverlay({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slide;
  late Animation<double> _fade;

  Timer? _timer; // 🔥 thêm

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(_controller);

    _controller.forward();

    // 🔥 dùng Timer thay vì Future
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;

      try {
        await _controller.reverse();
      } catch (_) {
        return;
      }

      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // 🔥 QUAN TRỌNG
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isError ? Colors.red[700] : Colors.green[700],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
