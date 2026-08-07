import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

  Widget adminDatePicker(
  BuildContext context,
    String label,
    DateTime? selectedDate,
    Function(DateTime) onDateSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final DateTime? picked = await showDatePicker(
              context: context,
              initialDate: selectedDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (picked != null) {
              onDateSelected(picked);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Color(0xFF090A4F),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selectedDate != null
                        ? DateFormat('MMM d, yyyy').format(selectedDate)
                        : 'Select date',
                    style: TextStyle(
                      fontSize: 12,
                      color: selectedDate != null
                          ? const Color(0xFF090A4F)
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
                if (selectedDate != null)
                  GestureDetector(
                    onTap: () => onDateSelected(DateTime(1900)),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }


  Widget adminFormField(
  BuildContext context,
    String label,
    TextEditingController controller,
    String hint, {
    bool isDate = false,
    bool isTime = false,
    bool isMultiline = false,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090A4F),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: isDate || isTime,
          maxLines: isMultiline ? 4 : 1,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null && !isDate && !isTime && !isMultiline
                ? Icon(icon, size: 20, color: Colors.grey.shade600)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF090A4F), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            suffixIcon: isDate
                ? IconButton(
                    icon: const Icon(Icons.calendar_today, size: 20),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        controller.text = DateFormat(
                          'MM/dd/yyyy',
                        ).format(picked);
                      }
                    },
                  )
                : isTime
                ? IconButton(
                    icon: const Icon(Icons.access_time, size: 20),
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null && context.mounted) {
                        controller.text = picked.format(context);
                      }
                    },
                  )
                : null,
          ),
        ),
      ],
    );
  }
