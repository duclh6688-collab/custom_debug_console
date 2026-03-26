import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../event_bus.dart';
import '../../models.dart';

class NetworkTab extends StatefulWidget {
  const NetworkTab({super.key});

  @override
  State<NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<NetworkTab> {
  final List<LogEvent> _items = <LogEvent>[];
  final Map<String, NetworkRequestGroup> _groupedRequests = {};
  final TextEditingController _search = TextEditingController();
  String? _methodFilter;
  StreamSubscription<LogEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _items.addAll(DebugBus.instance.logsSnapshot.where(_isNetworkLog));
    _rebuildGroupedRequests();
    _sub = DebugBus.instance.logsStream.listen((e) {
      if (_isNetworkLog(e)) {
        setState(() {
          _items.add(e);
          _rebuildGroupedRequests();
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _search.dispose();
    super.dispose();
  }

  bool _isNetworkLog(LogEvent e) {
    return e.tag != null &&
        (e.tag!.startsWith('HTTP_') ||
            e.tag!.startsWith('DIO_') ||
            e.tag!.contains('NETWORK') ||
            e.tag!.contains('API'));
  }

  void _rebuildGroupedRequests() {
    _groupedRequests.clear();

    for (final event in _items) {
      final networkData = _parseNetworkData(event.message);
      final method = networkData['method'] ?? _extractMethodFromTag(event.tag);
      final url = networkData['url'] ?? _extractUrlFromMessage(event.message);
      final key = '$method:$url';

      if (_groupedRequests.containsKey(key)) {
        // Update existing group
        final existing = _groupedRequests[key]!;
        final updatedEvents = [...existing.events, event];

        // Determine the most current status from all events
        int? statusCode = existing.statusCode;
        DateTime? lastResponseTime = existing.lastResponseTime;
        bool hasError = existing.hasError;

        // Check if this event provides status information
        if (event.tag?.contains('RES') == true ||
            event.tag?.contains('ERR') == true) {
          // Try to parse status code from various formats
          final statusMatch = RegExp(r'(?:Status:\s*|🟢\s*|🔴\s*)(\d+)')
              .firstMatch(event.message);
          if (statusMatch != null) {
            statusCode = int.tryParse(statusMatch.group(1)!);
          }
          lastResponseTime = event.ts;

          // Check if this is an error response
          if (event.tag?.contains('ERR') == true ||
              event.level == LogLevel.error ||
              (statusCode != null && statusCode >= 400)) {
            hasError = true;
          }
        }

        _groupedRequests[key] = NetworkRequestGroup(
          key: key,
          method: method,
          url: url,
          events: updatedEvents,
          firstRequestTime: existing.firstRequestTime,
          lastResponseTime: lastResponseTime,
          statusCode: statusCode,
          hasError: hasError,
        );
      } else {
        // Create new group - always start as pending
        _groupedRequests[key] = NetworkRequestGroup(
          key: key,
          method: method,
          url: url,
          events: [event],
          firstRequestTime: event.ts,
          // Don't set response time or status yet - this will show as PENDING
        );
      }
    }
  }

  String _extractMethodFromTag(String? tag) {
    if (tag == null) return 'UNKNOWN';

    // Extract method from tags like "HTTP_REQ", "DIO_REQ"
    final methods = [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'HEAD',
      'OPTIONS'
    ];
    for (final method in methods) {
      if (tag.contains(method)) return method;
    }
    return 'UNKNOWN';
  }

  String _extractUrlFromMessage(String message) {
    // Try to extract URL from first line or anywhere in the message
    final lines = message.split('\n');
    for (final line in lines) {
      if (line.contains('http')) {
        // Extract URL pattern
        final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(line);
        if (urlMatch != null) {
          return urlMatch.group(0)!;
        }
      }
    }

    // If no URL found, use the first line as identifier
    return lines.isNotEmpty ? lines[0].trim() : message;
  }

  Map<String, String?> _parseNetworkData(String message) {
    final lines = message.split('\n');
    String? method,
        url,
        statusCode,
        requestHeaders,
        requestBody,
        responseHeaders,
        responseBody;

    // Parse HTTP method and URL
    final firstLine = lines.isNotEmpty ? lines[0] : '';
    final methodMatch =
        RegExp(r'(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)\s+(.+?)(?:\s|$)')
            .firstMatch(firstLine);
    if (methodMatch != null) {
      method = methodMatch.group(1);
      url = methodMatch.group(2);
    } else if (firstLine.contains('http')) {
      url = firstLine;
    }

    // Parse status code
    final statusMatch = RegExp(r'Status:\s*(\d+)').firstMatch(message);
    statusCode = statusMatch?.group(1);

    // Parse request/response sections
    int currentSection =
        0; // 0: none, 1: request headers, 2: request body, 3: response headers, 4: response body
    StringBuffer currentBuffer = StringBuffer();

    for (String line in lines) {
      final lowerLine = line.toLowerCase().trim();

      if (lowerLine.contains('request headers:') ||
          lowerLine.contains('request header:')) {
        if (currentSection > 0) {
          _saveSection(
              currentSection,
              currentBuffer.toString().trim(),
              method,
              url,
              statusCode,
              requestHeaders,
              requestBody,
              responseHeaders,
              responseBody);
        }
        currentSection = 1;
        currentBuffer.clear();
      } else if (lowerLine.contains('request body:') ||
          lowerLine.contains('request payload:')) {
        if (currentSection > 0) {
          _saveSection(
              currentSection,
              currentBuffer.toString().trim(),
              method,
              url,
              statusCode,
              requestHeaders,
              requestBody,
              responseHeaders,
              responseBody);
        }
        currentSection = 2;
        currentBuffer.clear();
      } else if (lowerLine.contains('response headers:') ||
          lowerLine.contains('response header:')) {
        if (currentSection > 0) {
          _saveSection(
              currentSection,
              currentBuffer.toString().trim(),
              method,
              url,
              statusCode,
              requestHeaders,
              requestBody,
              responseHeaders,
              responseBody);
        }
        currentSection = 3;
        currentBuffer.clear();
      } else if (lowerLine.contains('response body:') ||
          lowerLine.contains('response:')) {
        if (currentSection > 0) {
          _saveSection(
              currentSection,
              currentBuffer.toString().trim(),
              method,
              url,
              statusCode,
              requestHeaders,
              requestBody,
              responseHeaders,
              responseBody);
        }
        currentSection = 4;
        currentBuffer.clear();
      } else if (currentSection > 0 && line.trim().isNotEmpty) {
        currentBuffer.writeln(line);
      }
    }

    // Save the last section
    if (currentSection > 0) {
      final content = currentBuffer.toString().trim();
      switch (currentSection) {
        case 1:
          requestHeaders = content;
          break;
        case 2:
          requestBody = content;
          break;
        case 3:
          responseHeaders = content;
          break;
        case 4:
          responseBody = content;
          break;
      }
    }

    return {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'requestHeaders': requestHeaders,
      'requestBody': requestBody,
      'responseHeaders': responseHeaders,
      'responseBody': responseBody,
    };
  }

  void _saveSection(
      int section,
      String content,
      String? method,
      String? url,
      String? statusCode,
      String? requestHeaders,
      String? requestBody,
      String? responseHeaders,
      String? responseBody) {
    // This is a placeholder method to handle section saving logic if needed
    // Currently, the parsing is handled in the main _parseNetworkData method
  }

  String _generateCurlCommand(Map<String, String?> data) {
    final method = data['method'] ?? 'GET';
    final url = data['url'] ?? '';
    final requestHeaders = data['requestHeaders'] ?? '';
    final requestBody = data['requestBody'] ?? '';

    StringBuffer curl = StringBuffer();
    curl.write('curl -X $method');

    // Add headers
    if (requestHeaders.isNotEmpty) {
      final headerLines = requestHeaders.split('\n');
      for (String headerLine in headerLines) {
        final trimmed = headerLine.trim();
        if (trimmed.isNotEmpty && trimmed.contains(':')) {
          curl.write(' \\\n  -H "$trimmed"');
        }
      }
    }

    // Add body
    if (requestBody.isNotEmpty && method != 'GET') {
      curl.write(' \\\n  -d \'$requestBody\'');
    }

    // Add URL
    curl.write(' \\\n  "$url"');

    return curl.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Filter grouped requests
    final filteredGroups = _groupedRequests.values.where((group) {
      final q = _search.text.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          group.method.toLowerCase().contains(q) ||
          group.url.toLowerCase().contains(q) ||
          group.events.any((e) =>
              e.message.toLowerCase().contains(q) ||
              (e.tag?.toLowerCase().contains(q) ?? false));

      final matchesMethod =
          _methodFilter == null || group.method.contains(_methodFilter!);

      return matchesSearch && matchesMethod;
    }).toList()
      ..sort((a, b) => b.firstRequestTime.compareTo(a.firstRequestTime));

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
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search network requests...',
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
          ),
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.network_wifi_outlined,
                            size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 16),
                        Text(
                          'No network requests yet',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredGroups.length,
                    itemBuilder: (context, index) {
                      final group = filteredGroups[index];
                      return _buildNetworkRequestCard(group);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkRequestCard(NetworkRequestGroup group) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey[800],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
            color: group.statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: group.statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: group.statusColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Center(
            child: group.statusCode == null
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(group.statusColor),
                    ),
                  )
                : Icon(
                    group.hasError
                        ? Icons.error_outline
                        : group.statusCode! >= 200 && group.statusCode! < 300
                            ? Icons.check_circle_outline
                            : Icons.warning_amber_outlined,
                    color: group.statusColor,
                    size: 20,
                  ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Method and Status Row
            Row(
              children: [
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: group.statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    group.statusDisplay,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Duration or Loading indicator
                if (group.duration != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(
                          '${group.duration!.inMilliseconds}ms',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[700],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Loading...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Full URL with method
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: group.statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    group.method,
                    style: TextStyle(
                      color: group.statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    group.url,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            // Status description
            const SizedBox(height: 4),
            Text(
              group.statusDescription,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _formatTimestamp(group.firstRequestTime),
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
              const SizedBox(width: 12),
              Icon(Icons.list_alt, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                '${group.events.length} event${group.events.length == 1 ? '' : 's'}',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
              if (group.lastResponseTime != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle_outline,
                    size: 12, color: Colors.green[400]),
                const SizedBox(width: 4),
                Text(
                  'Completed',
                  style: TextStyle(color: Colors.green[400], fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[850]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Copy Buttons Row for the group
                _buildGroupCopyButtonsRow(group),
                const SizedBox(height: 12),
                // All events in this group
                ...group.events.map((event) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getTagColor(event.tag),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  event.tag ?? 'LOG',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 10),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(event.ts),
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            event.message,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTagColor(String? tag) {
    if (tag == null) return Colors.grey;
    if (tag.contains('REQ')) return Colors.blue;
    if (tag.contains('RES')) return Colors.green;
    if (tag.contains('ERR')) return Colors.red;
    return Colors.purple;
  }

  Widget _buildGroupCopyButtonsRow(NetworkRequestGroup group) {
    // Combine all events into a comprehensive data structure
    final allData = StringBuffer();
    final requestData = StringBuffer();
    final responseData = StringBuffer();

    for (final event in group.events) {
      allData.writeln('--- ${event.tag} (${_formatTimestamp(event.ts)}) ---');
      allData.writeln(event.message);
      allData.writeln();

      if (event.tag?.contains('REQ') == true) {
        requestData.writeln(event.message);
      } else if (event.tag?.contains('RES') == true ||
          event.tag?.contains('ERR') == true) {
        responseData.writeln(event.message);
      }
    }

    // Parse the first request event for cURL generation
    final firstRequestEvent =
        group.events.where((e) => e.tag?.contains('REQ') == true).firstOrNull;
    Map<String, String?>? curlData;
    if (firstRequestEvent != null) {
      curlData = _parseNetworkData(firstRequestEvent.message);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Copy All
        ElevatedButton.icon(
          onPressed: () =>
              _copyToClipboard(allData.toString().trim(), 'All network data'),
          icon: Icon(Icons.copy_all, size: 16),
          label: Text('Copy All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),

        // Copy Request Only
        if (requestData.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () =>
                _copyToClipboard(requestData.toString().trim(), 'Request data'),
            icon: Icon(Icons.upload, size: 16),
            label: Text('Copy Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

        // Copy Response Only
        if (responseData.isNotEmpty)
          ElevatedButton.icon(
            onPressed: () => _copyToClipboard(
                responseData.toString().trim(), 'Response data'),
            icon: Icon(Icons.download, size: 16),
            label: Text('Copy Response'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

        // Copy as cURL
        if (curlData != null)
          ElevatedButton.icon(
            onPressed: () => _copyCurl(curlData!),
            icon: Icon(Icons.terminal, size: 16),
            label: Text('Copy cURL'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[700],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    }
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

  void _copyCurl(Map<String, String?> networkData) {
    final curlCommand = _generateCurlCommand(networkData);
    _copyToClipboard(curlCommand, 'cURL command');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
