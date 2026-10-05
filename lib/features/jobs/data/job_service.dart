import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:alumni_system/features/jobs/application/job_expiration.dart';
import 'package:alumni_system/features/jobs/models/job_posting_model.dart';

/// Job postings data access — Supabase only.
class JobService {
  JobService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  /// Session-scoped view debounce (prevents rapid duplicate increments).
  static final Set<String> _viewedThisSession = <String>{};

  /// Avoid re-scanning all active jobs for expiration on every Home/Jobs open.
  static DateTime? _lastExpireRun;
  static const _expireCooldown = Duration(minutes: 5);

  Future<void> addJobPosting(JobPosting job) async {
    try {
      await _supabase.from('jobs').upsert(job.toSupabaseRow(), onConflict: 'id');
    } catch (e) {
      throw Exception('Error adding job posting: $e');
    }
  }

  /// Active jobs for alumni — runs expiration first.
  Future<List<JobPosting>> getActiveJobs() async {
    await expirePastDeadlineJobs();
    final jobs = await _getJobsFromSupabase(status: 'active');
    jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    return jobs;
  }

  Future<List<JobPosting>> getAllJobs({bool expireFirst = true}) async {
    if (expireFirst) await expirePastDeadlineJobs();
    final jobs = await _getJobsFromSupabase();
    jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    return jobs;
  }

  Future<List<JobPosting>> getJobsByStatus(String status) async {
    await expirePastDeadlineJobs();
    final jobs = await _getJobsFromSupabase(status: status);
    jobs.sort((a, b) => b.postedDate.compareTo(a.postedDate));
    return jobs;
  }

  Future<JobPosting?> getJobPosting(String jobId) async {
    try {
      final row = await _supabase
          .from('jobs')
          .select()
          .eq('id', jobId)
          .maybeSingle();
      if (row == null) return null;
      return JobPosting.fromSupabaseRow(row);
    } catch (e) {
      throw Exception('Error fetching job posting: $e');
    }
  }

  Future<void> updateJobPosting(JobPosting job) async {
    try {
      await _supabase.from('jobs').upsert(job.toSupabaseRow(), onConflict: 'id');
    } catch (e) {
      throw Exception('Error updating job posting: $e');
    }
  }

  Future<void> deleteJobPosting(String jobId) async {
    try {
      await _supabase.from('jobs').delete().eq('id', jobId);
    } catch (e) {
      throw Exception('Error deleting job posting: $e');
    }
  }

  Future<int> getTotalJobsCount() async {
    try {
      return await _supabase.from('jobs').count(CountOption.exact);
    } catch (e) {
      throw Exception('Error fetching jobs count: $e');
    }
  }

  Future<int> getActiveJobsCount() async {
    try {
      await expirePastDeadlineJobs();
      return await _supabase
          .from('jobs')
          .count(CountOption.exact)
          .eq('status', 'active');
    } catch (e) {
      throw Exception('Error fetching active jobs count: $e');
    }
  }

  /// Marks past-deadline active jobs as expired.
  /// Cooldown prevents duplicate full-table scans on rapid Home/Jobs opens.
  Future<int> expirePastDeadlineJobs({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastExpireRun != null &&
        now.difference(_lastExpireRun!) < _expireCooldown) {
      return 0;
    }
    _lastExpireRun = now;

    try {
      // Only columns needed to detect + update expired actives.
      final rows = await _supabase
          .from('jobs')
          .select('id, status, data')
          .eq('status', 'active');
      final jobs = rows.map(JobPosting.fromSupabaseRow).toList();
      final toExpire = JobExpiration.jobsNeedingExpire(jobs);
      for (final job in toExpire) {
        final expired = job.copyWith(status: 'expired', isActive: false);
        await _supabase
            .from('jobs')
            .upsert(expired.toSupabaseRow(), onConflict: 'id');
      }
      return toExpire.length;
    } catch (_) {
      return 0;
    }
  }

  /// Increments views once per job per app session (alumni details open).
  Future<void> incrementViewCount(String jobId) async {
    if (jobId.isEmpty || _viewedThisSession.contains(jobId)) return;
    _viewedThisSession.add(jobId);
    try {
      await _supabase.rpc('increment_job_views', params: {'p_job_id': jobId});
    } catch (_) {
      _viewedThisSession.remove(jobId);
    }
  }

  Future<void> incrementApplicationCount(String jobId) async {
    final job = await getJobPosting(jobId);
    if (job == null) return;
    try {
      await _supabase.from('jobs').update({
        'data': {
          ...job.toSupabaseRow()['data'] as Map<String, dynamic>,
          'applications': job.applications + 1,
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', jobId);
    } catch (e) {
      throw Exception('Error incrementing application count: $e');
    }
  }

  /// Favorite counts keyed by job id (admin cards).
  Future<Map<String, int>> countFavoritesByJobIds(Iterable<String> jobIds) async {
    final ids = jobIds.where((id) => id.isNotEmpty).toList();
    if (ids.isEmpty) return {};
    try {
      final rows = await _supabase
          .from('favorite_jobs')
          .select('job_id')
          .inFilter('job_id', ids);
      final counts = <String, int>{};
      for (final row in rows) {
        final id = row['job_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  Future<List<JobPosting>> _getJobsFromSupabase({String? status}) async {
    try {
      var query = _supabase.from('jobs').select();
      if (status != null) {
        query = query.eq('status', status);
      }
      final rows = await query;
      return rows.map(JobPosting.fromSupabaseRow).toList();
    } catch (e) {
      throw Exception('Error fetching job postings: $e');
    }
  }
}
