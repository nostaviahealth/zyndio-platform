import 'package:flutter/material.dart';
import 'package:platform_wearables/platform_wearables.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen> {
  bool _isLoading = true;
  List<SleepSession> _sleepData = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSleepData();
  }

  Future<void> _fetchSleepData() async {
    try {
      final sleepData = await Zyndio.getSleep(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _sleepData = sleepData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Sleep Dashboard', style: TextStyle(color: context.nc.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nc.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: BrandColors.emerald500))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Failed to load sleep data:\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BrandColors.red500),
                    ),
                  ),
                )
              : _sleepData.isEmpty
                  ? Center(
                      child: Text(
                        'No sleep data found for the last 7 days.',
                        style: TextStyle(color: context.nc.textTertiary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _sleepData.length,
                      itemBuilder: (context, index) {
                        final session = _sleepData[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.nc.cardSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.nc.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF818CF8).withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.moon, color: Color(0xFF818CF8)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Duration',
                                      style: TextStyle(
                                        color: context.nc.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDuration(session.totalSleepSec),
                                      style: TextStyle(
                                        color: context.nc.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Score',
                                    style: TextStyle(
                                      color: context.nc.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    session.sleepScore != null ? '${session.sleepScore}' : '--',
                                    style: TextStyle(
                                      color: _getScoreColor(session.sleepScore),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Color _getScoreColor(int? score) {
    if (score == null) return BrandColors.slate500;
    if (score >= 80) return BrandColors.emerald500;
    if (score >= 60) return BrandColors.amber500;
    return BrandColors.red500;
  }
}
