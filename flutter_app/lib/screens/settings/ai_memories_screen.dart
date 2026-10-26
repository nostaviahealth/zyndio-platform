import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/memory_service.dart';
import 'dart:ui' as ui;

class AIMemoriesScreen extends ConsumerStatefulWidget {
  const AIMemoriesScreen({super.key});

  @override
  ConsumerState<AIMemoriesScreen> createState() => _AIMemoriesScreenState();
}

class _AIMemoriesScreenState extends ConsumerState<AIMemoriesScreen> {
  bool _isLoading = true;
  String? _error;
  List<MemoryFragment> _memories = [];
  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = ref.read(memoryServiceProvider);
      final memories = await service.fetchAllMemories();
      if (mounted) {
        setState(() {
          _memories = memories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load memories. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteMemory(MemoryFragment memory) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B), // Solid Slate-800 for better readability
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: context.nc.cardBorder.withValues(alpha: 0.2)),
        ),
        title: Text('Delete Memory', style: TextStyle(color: context.nc.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'Are you sure you want the AI to forget this? \"${memory.content.length > 60 ? '${memory.content.substring(0, 60)}...' : memory.content}\"',
          style: TextStyle(color: context.nc.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: context.nc.textTertiary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _deletingId = memory.id);
      try {
        final success = await ref.read(memoryServiceProvider).deleteMemory(memory.id);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Memory deleted'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: context.nc.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          await _loadMemories();
        }
      } finally {
        if (mounted) setState(() => _deletingId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: context.nc.scaffoldBg.withValues(alpha: 0.8),
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, color: context.nc.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI Memories',
          style: TextStyle(
            color: context.nc.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(LucideIcons.refreshCw, color: context.nc.textSecondary, size: 20),
            onPressed: _loadMemories,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMemories,
        displacement: 100,
        color: context.nc.textPrimary,
        backgroundColor: context.nc.cardSurface,
        child: _isLoading && _memories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : _memories.isEmpty
                    ? _buildEmptyState()
                    : _buildMemoryList(),
      ),
    );
  }

  Widget _buildMemoryList() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, 20),
      itemCount: _memories.length,
      itemBuilder: (context, index) {
        final memory = _memories[index];
        return _MemoryCard(
          memory: memory,
          isDeleting: _deletingId == memory.id,
          onDelete: () => _deleteMemory(memory),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.alertCircle, size: 48, color: Colors.redAccent.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: context.nc.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadMemories,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.nc.textPrimary,
              foregroundColor: context.nc.scaffoldBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height - 100,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.nc.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.brain, size: 64, color: context.nc.textTertiary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 32),
            Text(
              'Your AI is Learning',
              style: TextStyle(
                color: context.nc.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'As you chat with Zyndio, I extract key facts about your health, goals, and preferences to provide better guidance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.nc.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _buildFeatureHint(LucideIcons.checkCircle2, "Personalized recommendations"),
            _buildFeatureHint(LucideIcons.checkCircle2, "Long-term health context"),
            _buildFeatureHint(LucideIcons.checkCircle2, "Cross-referenced insights"),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureHint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: context.nc.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryFragment memory;
  final bool isDeleting;
  final VoidCallback onDelete;

  const _MemoryCard({
    required this.memory,
    this.isDeleting = false,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = "${memory.createdAt.day} ${_getMonth(memory.createdAt.month)} ${memory.createdAt.year}";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.nc.cardBorder.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _getTypeColor(memory.memoryType).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          memory.memoryType.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: _getTypeColor(memory.memoryType),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      if (isDeleting)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
                        )
                      else
                        IconButton(
                          icon: Icon(LucideIcons.x, size: 18, color: context.nc.textTertiary),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    memory.content,
                    style: TextStyle(
                      color: context.nc.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(LucideIcons.calendar, size: 12, color: context.nc.textTertiary),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: context.nc.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'user_fact':
        return const Color(0xFF3B82F6); // Blue
      case 'habit_insight':
        return const Color(0xFF10B981); // Emerald
      case 'conversation_summary':
        return const Color(0xFFA855F7); // Purple
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
