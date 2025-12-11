import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/job.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

abstract class JobState {}

class JobInitial extends JobState {}

class JobLoading extends JobState {}

class JobLoaded extends JobState {
  final Job job;
  JobLoaded(this.job);
}

class JobError extends JobState {
  final String message;
  JobError(this.message);
}

// change...
class JobCubit extends Cubit<JobState> {
  final JobRepository jobRepository;
  JobCubit(this.jobRepository) : super(JobInitial());


  Future<void> createJob(Job job) async {
    try {
      await jobRepository.create(job);
      emit(JobLoaded(job));
      print('Job created successfully ${job.id}');
    } catch (e) {
      emit(JobError(e.toString()));
    }

    final id = await jobRepository.create(job);
    final created = await jobRepository.fetch(id);
    print("Created job from Firestore: ${created.toMap()}");
  }

  Future<void> acceptJob(Job job) async {
    try {
      await jobRepository.updateStatus(job.id!, JobStatus.accepted);
      emit(JobLoaded(job.copyWith(status: JobStatus.accepted)));
    } catch (e) {
      emit(JobError(e.toString()));
    }
  }
}

class JobRepository {
  JobRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _jobs => _db.collection('jobs');

  /// Create a job. Returns the new document id.
  Future<String> create(Job job) async {
    final data =
        job.toMap()..addAll({
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    final doc = await _jobs.add(data);

    return doc.id;
  }

  /// Fetch a single job once.
  Future<Job> fetch(String jobId) async {
    final doc = await _jobs.doc(jobId).get();
    if (!doc.exists) {
      throw Exception('Job not found');
    }
    return Job.fromDoc(doc);
  }

  /// Watch a job in real-time.
  Stream<Job> watch(String jobId) {
    return _jobs.doc(jobId).snapshots().map((snap) {
      if (!snap.exists) {
        throw Exception('Job deleted');
      }
      return Job.fromDoc(snap);
    });
  }

  /// Update the job status with server timestamp.
  Future<void> updateStatus(String jobId, JobStatus status) {
    return _jobs.doc(jobId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Assign or change the mechanic for a job.
  Future<void> assignMechanic(String jobId, String mechanicId) {
    return _jobs.doc(jobId).update({
      'mechanicId': mechanicId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update monetary fields (estimate/final).
  Future<void> updateCosts(
    String jobId, {
    double? estimatedCost,
    double? finalCost,
  }) {
    final patch = <String, dynamic>{
      if (estimatedCost != null) 'estimatedCost': estimatedCost,
      if (finalCost != null) 'finalCost': finalCost,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return _jobs.doc(jobId).update(patch);
  }

  /// Generic partial update (e.g., notes, brand, location, etc.).
  Future<void> update(String jobId, Map<String, dynamic> patch) {
    return _jobs.doc(jobId).update({
      ...patch,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// List jobs for a given user (as customer or mechanic), optionally by status.
  Future<List<Job>> listForUser({
    required String userId,
    required bool asMechanic,
    JobStatus? status,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = _jobs
        .where(asMechanic ? 'mechanicId' : 'customerId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (status != null) {
      q = q.where('status', isEqualTo: status.name);
    }

    final snap = await q.get();
    return snap.docs.map(Job.fromDoc).toList();
  }

  /// Delete a job (use with caution).
  Future<void> delete(String jobId) => _jobs.doc(jobId).delete();
}
