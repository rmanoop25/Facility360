import 'package:easy_localization/easy_localization.dart';

import '../../domain/enums/issue_status.dart';

/// Dashboard statistics model matching Laravel backend DashboardController response
class DashboardStatsModel {
  final IssueStatsModel issues;
  final Map<String, int> issuesByPriority;
  final EntityCountModel tenants;
  final EntityCountModel serviceProviders;
  final List<RecentIssueModel> recentIssues;

  const DashboardStatsModel({
    required this.issues,
    required this.issuesByPriority,
    required this.tenants,
    required this.serviceProviders,
    required this.recentIssues,
  });

  factory DashboardStatsModel.fromJson(Map<String, dynamic> json) {
    // Parse issues_by_priority map
    final priorityMap = <String, int>{};
    if (json['issues_by_priority'] is Map) {
      (json['issues_by_priority'] as Map).forEach((key, value) {
        priorityMap[key.toString()] = (value as num?)?.toInt() ?? 0;
      });
    }

    return DashboardStatsModel(
      issues: IssueStatsModel.fromJson(
        json['issues'] as Map<String, dynamic>? ?? {},
      ),
      issuesByPriority: priorityMap,
      tenants: EntityCountModel.fromJson(
        json['tenants'] as Map<String, dynamic>? ?? {},
      ),
      serviceProviders: EntityCountModel.fromJson(
        json['service_providers'] as Map<String, dynamic>? ?? {},
      ),
      recentIssues: (json['recent_issues'] as List<dynamic>?)
              ?.map((e) => RecentIssueModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'issues': issues.toJson(),
      'issues_by_priority': issuesByPriority,
      'tenants': tenants.toJson(),
      'service_providers': serviceProviders.toJson(),
      'recent_issues': recentIssues.map((e) => e.toJson()).toList(),
    };
  }
}

/// Issue statistics from dashboard
class IssueStatsModel {
  final int total;
  final int pending;
  final int assigned;
  final int inProgress;
  final int finished;
  final int completed;
  final int cancelled;
  final int todayCreated;
  final int monthCreated;
  final int awaitingApproval;

  const IssueStatsModel({
    required this.total,
    required this.pending,
    required this.assigned,
    required this.inProgress,
    required this.finished,
    required this.completed,
    required this.cancelled,
    required this.todayCreated,
    required this.monthCreated,
    required this.awaitingApproval,
  });

  /// Get count of active issues (assigned + in_progress + on_hold)
  int get activeCount => assigned + inProgress;

  factory IssueStatsModel.fromJson(Map<String, dynamic> json) {
    return IssueStatsModel(
      total: _parseInt(json['total']),
      pending: _parseInt(json['pending']),
      assigned: _parseInt(json['assigned']),
      inProgress: _parseInt(json['in_progress']),
      finished: _parseInt(json['finished']),
      completed: _parseInt(json['completed']),
      cancelled: _parseInt(json['cancelled']),
      todayCreated: _parseInt(json['today_created']),
      monthCreated: _parseInt(json['month_created']),
      awaitingApproval: _parseInt(json['awaiting_approval']),
    );
  }

  /// Helper to parse int from string or int
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is num) return value.toInt();
    return 0;
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'pending': pending,
      'assigned': assigned,
      'in_progress': inProgress,
      'finished': finished,
      'completed': completed,
      'cancelled': cancelled,
      'today_created': todayCreated,
      'month_created': monthCreated,
      'awaiting_approval': awaitingApproval,
    };
  }
}

/// Entity count (tenants, service providers)
class EntityCountModel {
  final int total;
  final int active;

  const EntityCountModel({required this.total, required this.active});

  factory EntityCountModel.fromJson(Map<String, dynamic> json) {
    return EntityCountModel(
      total: (json['total'] as num?)?.toInt() ?? 0,
      active: (json['active'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'total': total,
      'active': active,
    };
  }
}

/// Recent issue from dashboard
class RecentIssueModel {
  final int id;
  final String title;
  final String status;
  final String statusLabel;
  final String priority;
  final String tenantName;
  final String? createdAt;

  const RecentIssueModel({
    required this.id,
    required this.title,
    required this.status,
    required this.statusLabel,
    required this.priority,
    required this.tenantName,
    this.createdAt,
  });

  factory RecentIssueModel.fromJson(Map<String, dynamic> json) {
    return RecentIssueModel(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      statusLabel: json['status_label'] as String? ?? '',
      priority: json['priority'] as String? ?? '',
      tenantName: json['tenant_name'] as String? ?? 'N/A',
      createdAt: json['created_at'] as String?,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'status_label': statusLabel,
      'priority': priority,
      'tenant_name': tenantName,
      'created_at': createdAt,
    };
  }

  /// Get time ago string from createdAt
  String get timeAgo {
    if (createdAt == null) return '';
    try {
      final date = DateTime.parse(createdAt!);
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) {
        return 'common.ago'.tr(namedArgs: {'time': '${diff.inDays} ${'time.day'.tr()}'});
      } else if (diff.inHours > 0) {
        return 'common.ago'.tr(namedArgs: {'time': '${diff.inHours} ${'time.hour'.tr()}'});
      } else if (diff.inMinutes > 0) {
        return 'common.ago'.tr(namedArgs: {'time': '${diff.inMinutes} ${'time.minute'.tr()}'});
      }
      return 'common.just_now'.tr();
    } catch (_) {
      return '';
    }
  }

  /// Get translated status label based on status value
  String get translatedStatusLabel {
    final issueStatus = IssueStatus.fromValue(status);
    return issueStatus?.label ?? statusLabel;
  }

  /// Get tenant unit from tenantName (format: "Name - Unit")
  String get tenantUnit {
    if (tenantName.contains(' - ')) {
      return tenantName.split(' - ').last;
    }
    return tenantName;
  }
}
