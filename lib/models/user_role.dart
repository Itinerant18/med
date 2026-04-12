enum UserRole {
  doctor,
  assistant;

  String get label {
    switch (this) {
      case UserRole.doctor:
        return 'Doctor';
      case UserRole.assistant:
        return 'Assistant';
    }
  }

  bool get isAdmin => this == UserRole.doctor;
}
