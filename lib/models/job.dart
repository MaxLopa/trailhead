import 'package:app1/models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'service_options.dart';

enum JobStatus { requested, accepted, inProgress, completed, cancelled }

enum PaymentStatus { noFee, feePaid, waitingPayment, paid, refunded }

/// The object representing a job created by a customer that will be queued for mechanics to accept
class Job {
  final String? id;
  final String? customerId;
  final String? mechanicId;

  final Service service;
  final Genre genre;
  final ServiceType serviceType;
  final String brand;

  final JobStatus status;
  final String? notes;

  final double? estimatedCost;
  final double? finalCost;

  final GeoPoint? location;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Job({
    this.id,
    this.customerId,
    this.mechanicId,
    required this.service,
    required this.genre,
    required this.serviceType,
    required this.brand,
    this.status = JobStatus.requested,
    this.notes,
    this.estimatedCost,
    this.finalCost,
    this.location,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'mechanicId': mechanicId,
      'serviceName': service.name,
      'genreName': genre.name,
      'serviceTypeName': serviceType.name,
      'brand': brand,
      'status': status.name,
      'notes': notes,
      'estimatedCost': estimatedCost,
      'finalCost': finalCost,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory Job.fromMap(Map<String, dynamic> map, {String? id}) {
    return Job(
      id: id ?? "",
      customerId: map['customerId'] as String,
      mechanicId: map['mechanicId'] as String?,
      service: Service(map['serviceName'] as String, const []),
      genre:
          map['genreName'] != null
              ? Genre(
                map['genreName'] as String,
                const [],
                applicableBrands: const [],
              )
              : Genre("Unknown", const [], applicableBrands: const []),

      serviceType:
          map['serviceTypeName'] != null
              ? ServiceType(map['serviceTypeName'] as String, const [])
              : ServiceType("Unknown", const []),

      brand: map['brand'] != null ? map['brand'] as String : "Unknown",
      notes: map['notes'] as String?,
      estimatedCost: (map['estimatedCost'] as num?)?.toDouble(),
      finalCost: (map['finalCost'] as num?)?.toDouble(),
      location: map['location'] as GeoPoint?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Job copyWith({
    String? id,
    String? customerId,
    String? mechanicId,
    Service? service,
    Genre? genre,
    ServiceType? serviceType,
    String? brand,
    JobStatus? status,
    String? notes,
    double? estimatedCost,
    double? finalCost,
    GeoPoint? location,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Job(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      mechanicId: mechanicId ?? this.mechanicId,
      service: service ?? this.service,
      genre: genre ?? this.genre,
      serviceType: serviceType ?? this.serviceType,
      brand: brand ?? this.brand,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      finalCost: finalCost ?? this.finalCost,
      location: location ?? this.location,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Booking {
  String? id;
  final JobStatus jobStatus;
  final PaymentStatus paymentStatus;

  final Job job;
  final String mechId;
  final String userId;

  Booking({
    required this.jobStatus,
    required this.paymentStatus,
    required this.job,
    required this.mechId,
    required this.userId,
    this.id
  });

  Booking copyWith({JobStatus? jobStatus, PaymentStatus? paymentStatus}) {
    return Booking(
      id: id,
      jobStatus: jobStatus ?? this.jobStatus,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      job: job,
      mechId: mechId,
      userId: userId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': '${mechId}|${userId}|${job.service.name}'
          .replaceAll(RegExp(r'\s+'), ''),
      'jobStatus': jobStatus.name, // enum -> string
      'paymentStatus': paymentStatus.name, // enum -> string
      'job': job.toMap(),
      'mechId': mechId,
      'userId': userId,
    };
  }

  factory Booking.fromMap(Map<String, dynamic> map) {
    return Booking(
      id: (map['id'] ?? '') as String,
      jobStatus: JobStatus.values.byName(map['jobStatus'] as String),
      paymentStatus: PaymentStatus.values.byName(
        map['paymentStatus'] as String,
      ),
      job: Job.fromMap((map['job'] as Map).cast<String, dynamic>()),
      mechId: (map['mechId'] ?? '') as String,
      userId: (map['userId'] ?? '') as String,
    );
  }
}
