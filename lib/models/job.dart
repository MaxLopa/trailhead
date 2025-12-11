import 'package:cloud_firestore/cloud_firestore.dart';
import 'service_options.dart';

enum JobStatus { requested, accepted, inProgress, completed, cancelled }

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

  factory Job.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Job(
      id: doc.id,
      customerId: data['customerId'] as String,
      mechanicId: data['mechanicId'] as String?,
      service: Service(data['serviceName'] as String, const []),
      genre:
          data['genreName'] != null
              ? Genre(
                data['genreName'] as String,
                const [],
                applicableBrands: const [],
              )
              : Genre("Unknown", const [], applicableBrands: const []),

      serviceType:
          data['serviceTypeName'] != null
              ? ServiceType(data['serviceTypeName'] as String, const [])
              : ServiceType("Unknown", const []),

      brand: data['brand'] != null ? data['brand'] as String : "Unknown",
      notes: data['notes'] as String?,
      estimatedCost: (data['estimatedCost'] as num?)?.toDouble(),
      finalCost: (data['finalCost'] as num?)?.toDouble(),
      location: data['location'] as GeoPoint?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
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
