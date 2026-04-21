import 'package:flutter/material.dart';
import 'package:mediflow/core/neu_widgets.dart';

class ExternalDoctorFields extends StatefulWidget {
  const ExternalDoctorFields({
    super.key,
    required this.nameController,
    required this.specializationController,
    required this.hospitalController,
    required this.phoneController,
  });

  final TextEditingController nameController;
  final TextEditingController specializationController;
  final TextEditingController hospitalController;
  final TextEditingController phoneController;

  @override
  State<ExternalDoctorFields> createState() => _ExternalDoctorFieldsState();
}

class _ExternalDoctorFieldsState extends State<ExternalDoctorFields> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NeuTextField(
          controller: widget.nameController,
          label: 'Doctor Name *',
          hint: 'Required',
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Doctor name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        NeuTextField(
          controller: widget.specializationController,
          label: 'Specialization',
          hint: 'Cardiology, General Medicine...',
        ),
        const SizedBox(height: 12),
        NeuTextField(
          controller: widget.hospitalController,
          label: 'Hospital',
          hint: 'Hospital or clinic name',
        ),
        const SizedBox(height: 12),
        NeuTextField(
          controller: widget.phoneController,
          label: 'Phone',
          keyboardType: TextInputType.phone,
          hint: 'Contact number',
        ),
      ],
    );
  }
}
