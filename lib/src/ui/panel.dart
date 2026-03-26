
import 'package:flutter/material.dart';
import 'tabs/logs_tab.dart';
import 'tabs/network_tab.dart';

class DebugPanel extends StatefulWidget {
  const DebugPanel({
    super.key, 
    required this.onClose,
    this.showNetworkTab = true,
  });

  final VoidCallback onClose;
  final bool showNetworkTab;

  @override
  State<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<DebugPanel> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.showNetworkTab ? 2 : 1,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: Material(
            elevation: 24,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.grey[900]!,
                    Colors.grey[800]!,
                  ],
                ),
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  if (_isExpanded) ...[
                    _buildTabBar(),
                    const Divider(height: 1, color: Colors.grey),
                    Expanded(child: _buildTabBarView()),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple[700]!, Colors.deepPurple[600]!],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.bug_report_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Debug Console',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Monitor logs & network activity',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            icon: AnimatedRotation(
              duration: const Duration(milliseconds: 300),
              turns: _isExpanded ? 0.5 : 0,
              child: const Icon(
                Icons.expand_more,
                color: Colors.white,
              ),
            ),
            tooltip: _isExpanded ? 'Minimize' : 'Expand',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
            ),
            tooltip: 'Close debug console',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.grey[850],
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.deepPurple[300],
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[400],
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.list_alt_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Logs'),
              ],
            ),
          ),
          if (widget.showNetworkTab)
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.network_check_rounded, size: 18),
                  const SizedBox(width: 8),
                  const Text('Network'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: _tabController,
      children: [
        const LogsTab(),
        if (widget.showNetworkTab)
          const NetworkTab(),
      ],
    );
  }
}
