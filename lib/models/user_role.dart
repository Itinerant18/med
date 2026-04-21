enum UserRole {
  headDoctor,
  doctor,
  assistant;

  /// Value used when writing the role to Supabase / other databases.
  /// Explicitly named to avoid shadowing Dart's built-in [Enum.name].
  String get databaseValue => switch (this) {
        UserRole.headDoctor => 'head_doctor',
        UserRole.doctor => 'doctor',
        UserRole.assistant => 'assistant',
      };

  String get label => switch (this) {
        UserRole.headDoctor => 'Head Doctor',
        UserRole.doctor => 'Doctor',
        UserRole.assistant => 'Agent',
      };

  bool get isSuperAdmin => this == UserRole.headDoctor;
  bool get isAdmin => this == UserRole.headDoctor || this == UserRole.doctor;
  bool get isAgent => this == UserRole.assistant;

  static UserRole fromString(String? value) => switch (value) {
        'head_doctor' => UserRole.headDoctor,
        'doctor' => UserRole.doctor,
        'assistant' => UserRole.assistant,
        _ => UserRole.assistant,
      };
}
