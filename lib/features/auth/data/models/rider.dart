/// Rider profile returned by `/auth/me` and `/auth/verify-otp`.
///
/// PII fields (aadharNumber, panNumber) are stored in memory only,
/// rendered read-only on Profile, and never logged.
class Rider {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? availabilityStatus; // active-free, active-busy, offline
  final bool? mustResetPassword;

  // KYC / profile (read-only, may be null)
  final String? aadharNumber;
  final String? panNumber;
  final String? vehicleNumber;
  final String? vehicleType;
  final String? profileImageUrl;
  final bool? isVerified;
  final bool? isActive;

  const Rider({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.availabilityStatus,
    this.mustResetPassword,
    this.aadharNumber,
    this.panNumber,
    this.vehicleNumber,
    this.vehicleType,
    this.profileImageUrl,
    this.isVerified,
    this.isActive,
  });

  factory Rider.fromJson(Map<String, dynamic> json) {
    return Rider(
      id: json['_id'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      availabilityStatus: json['availabilityStatus'] as String?,
      mustResetPassword: json['mustResetPassword'] as bool?,
      aadharNumber: json['aadharNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      vehicleType: json['vehicleType'] as String?,
      profileImageUrl: json['profileImageUrl'] as String?,
      isVerified: json['isVerified'] as bool?,
      isActive: json['isActive'] as bool?,
    );
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'availabilityStatus': availabilityStatus,
        'mustResetPassword': mustResetPassword,
        'aadharNumber': aadharNumber,
        'panNumber': panNumber,
        'vehicleNumber': vehicleNumber,
        'vehicleType': vehicleType,
        'profileImageUrl': profileImageUrl,
        'isVerified': isVerified,
        'isActive': isActive,
      };
}
