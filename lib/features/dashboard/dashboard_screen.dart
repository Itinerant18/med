import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mediflow/core/theme.dart';
import 'package:mediflow/features/dashboard/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('MediFlow Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            if (dashboardAsync.value?.isLive ?? false)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(dashboardProvider.notifier).refresh(),
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildSummaryCard('Today\'s Appointments', data.appointmentsCount.toString(), AppTheme.primaryTeal),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Pending Lab Results', data.pendingLabsCount.toString(), const Color(0xFFD97706)),
                    const SizedBox(width: 12),
                    _buildSummaryCard('Upcoming OT', data.upcomingOTCount.toString(), const Color(0xFFDC2626)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (data.highPriorityPatients.isNotEmpty) ...[
                _buildSectionHeader('Requires Attention'),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: data.highPriorityPatients.length,
                    itemBuilder: (context, i) {
                      final p = data.highPriorityPatients[i];
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EDF2),
                          borderRadius: BorderRadius.circular(12),
                          border: const Border(
                            left: BorderSide(color: Colors.red, width: 4),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFA3B1C6),
                              offset: Offset(3, 3),
                              blurRadius: 6,
                            ),
                            BoxShadow(
                              color: Colors.white,
                              offset: Offset(-3, -3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p['full_name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              p['service_status'] ?? 'Pending',
                              style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                            ),
                            Text(
                              'Dr. ${p['last_updated_by'] ?? '?'}',
                              style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildSectionHeader('Follow-ups Due'),
              _buildVisitList(data.todayVisits.where((v) => v['visit_type'] == 'OPD').toList()),
              const SizedBox(height: 24),
              _buildSectionHeader('Upcoming Appointments'),
              _buildVisitList(data.todayVisits),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String count, Color color) {
    return Container(
      width: 140,
      height: 90,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(count, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF718096),
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVisitList(List<Map<String, dynamic>> visits) {
    if (visits.isEmpty) return const Padding(padding: EdgeInsets.all(16.0), child: Text('No records found for today.'));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visits.length,
      itemBuilder: (context, index) {
        final visit = visits[index];
        final patientInfo = visit['patients'] as Map<String, dynamic>?;
        final patientName = patientInfo?['full_name']
            ?? visit['patient_name']
            ?? 'Unknown';
        final isHighPriority =
            patientInfo?['is_high_priority'] ?? false;
        final doctor = visit['doctors'];
        final String visitTime = DateFormat.jm().format(DateTime.parse(visit['visit_date']));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: isHighPriority ? Colors.red : Colors.transparent, width: 6)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              ListTile(
                title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$visitTime • ${visit['visit_type']}'),
                trailing: _buildStatusBadge(visit['test_status'] ?? 'pending'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Last changed by: Dr. ${doctor?['full_name'] ?? 'Staff'}', 
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = (status.toLowerCase() == 'completed') ? Colors.green : Colors.amber.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
