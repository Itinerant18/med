enum UserRole { doctor, assistant }

extension UserRoleX on UserRole {
  String get label => this == UserRole.doctor ? 'Doctor' : 'Assistant';
  bool get isAdmin => this == UserRole.doctor;
}
