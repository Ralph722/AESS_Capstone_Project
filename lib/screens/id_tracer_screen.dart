import 'package:flutter/material.dart';

class IdTracerScreen extends StatefulWidget {
  const IdTracerScreen({super.key});

  @override
  State<IdTracerScreen> createState() => _IdTracerScreenState();
}

class _IdTracerScreenState extends State<IdTracerScreen> {
  String _employmentStatus = 'Employed';
  final _monthsUnemployedController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _schoolIdController = TextEditingController();

  @override
  void dispose() {
    _monthsUnemployedController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(
              Icons.search,
              color: Color(0xFFFFD700),
              size: 28,
            ),
            const SizedBox(width: 8),
            const Text(
              'ID Tracer',
              style: TextStyle(
                color: Color(0xFF090A4F),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF090A4F),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Employment Status
                const Text(
                  'Employment Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF090A4F),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildRadioOption('Employed', 'Employed'),
                    const SizedBox(width: 24),
                    _buildRadioOption('Unemployed', 'Unemployed'),
                  ],
                ),
                const SizedBox(height: 24),

                // Months Unemployed (only show if Unemployed)
                if (_employmentStatus == 'Unemployed') ...[
                  _buildTextField(
                    controller: _monthsUnemployedController,
                    label: 'Months unemployed',
                    icon: Icons.calendar_today,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Contact Number Field
                _buildTextField(
                  controller: _contactNumberController,
                  label: 'Contact Number',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // School ID Number Field
                _buildTextField(
                  controller: _schoolIdController,
                  label: 'School ID Number',
                  icon: Icons.badge,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Not functional yet
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF090A4F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _monthsUnemployedController.clear();
                            _emailController.clear();
                            _contactNumberController.clear();
                            _schoolIdController.clear();
                            _employmentStatus = 'Employed';
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade200,
                          foregroundColor: const Color(0xFF090A4F),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRadioOption(String value, String label) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _employmentStatus = value;
        });
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(
                color: _employmentStatus == value
                    ? const Color(0xFF090A4F)
                    : Colors.grey,
                width: 2,
              ),
              color: _employmentStatus == value
                  ? const Color(0xFF090A4F)
                  : Colors.transparent,
            ),
            child: _employmentStatus == value
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: _employmentStatus == value
                  ? const Color(0xFF090A4F)
                  : Colors.grey,
              fontWeight: _employmentStatus == value
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

