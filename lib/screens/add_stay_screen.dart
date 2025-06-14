import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schengen/providers/stay_provider.dart';
import 'package:schengen/models/stay_record.dart';
import 'package:intl/intl.dart';
import 'package:time_machine/time_machine.dart';

class AddStayScreen extends StatefulWidget {
  final DateTime?
  initialEntryDate; // Keep these as DateTime for backward compatibility
  final DateTime? initialExitDate; // We'll convert to LocalDate in the state

  const AddStayScreen({super.key, this.initialEntryDate, this.initialExitDate});

  @override
  State<AddStayScreen> createState() => _AddStayScreenState();
}

class _AddStayScreenState extends State<AddStayScreen> {
  final _formKey = GlobalKey<FormState>();
  late LocalDate _entryDate;
  LocalDate? _exitDate;
  String _notes = '';
  late bool _isCurrentlyInSchengen;

  @override
  void initState() {
    super.initState();
    // Convert DateTime to LocalDate
    _entryDate = widget.initialEntryDate != null
        ? LocalDate.dateTime(widget.initialEntryDate!)
        : LocalDate.today();

    // Convert DateTime to LocalDate
    _exitDate = widget.initialExitDate != null
        ? LocalDate.dateTime(widget.initialExitDate!)
        : null;

    // If exit date is provided, user is not currently in Schengen
    _isCurrentlyInSchengen = widget.initialExitDate == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Schengen Stay'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Entry Date Field
              const Text(
                'Entry Date',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _selectDate(context, true),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('MMMM d, yyyy').format(
                      DateTime(
                        _entryDate.year,
                        _entryDate.monthOfYear,
                        _entryDate.dayOfMonth,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Still in Schengen Checkbox
              CheckboxListTile(
                title: const Text('I am currently in the Schengen Zone'),
                value: _isCurrentlyInSchengen,
                onChanged: (value) {
                  setState(() {
                    _isCurrentlyInSchengen = value ?? true;
                    if (_isCurrentlyInSchengen) {
                      _exitDate = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 16),

              // Exit Date Field (shown only if not currently in Schengen)
              if (!_isCurrentlyInSchengen) ...[
                const Text(
                  'Exit Date',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context, false),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _exitDate != null
                          ? DateFormat('MMMM d, yyyy').format(
                              DateTime(
                                _exitDate!.year,
                                _exitDate!.monthOfYear,
                                _exitDate!.dayOfMonth,
                              ),
                            )
                          : 'Select exit date',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Notes Field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'E.g., Holiday in Italy, Business trip, etc.',
                ),
                maxLines: 3,
                onChanged: (value) => _notes = value,
              ),
              const SizedBox(height: 32),

              // Submit Button
              ElevatedButton(
                onPressed: _saveStay,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Stay', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isEntryDate) async {
    // Convert LocalDate to DateTime for the DatePicker
    final initialDateTimeValue = isEntryDate
        ? DateTime(
            _entryDate.year,
            _entryDate.monthOfYear,
            _entryDate.dayOfMonth,
          )
        : _exitDate != null
        ? DateTime(
            _exitDate!.year,
            _exitDate!.monthOfYear,
            _exitDate!.dayOfMonth,
          )
        : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDateTimeValue,
      firstDate: isEntryDate
          ? DateTime(2000)
          : DateTime(
              _entryDate.year,
              _entryDate.monthOfYear,
              _entryDate.dayOfMonth,
            ),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (picked != null) {
      setState(() {
        if (isEntryDate) {
          // Convert DateTime to LocalDate
          _entryDate = LocalDate.dateTime(picked);

          // Reset exit date if entry date is after the current exit date
          if (_exitDate != null) {
            final entryDateTime = DateTime(
              _entryDate.year,
              _entryDate.monthOfYear,
              _entryDate.dayOfMonth,
            );
            final exitDateTime = DateTime(
              _exitDate!.year,
              _exitDate!.monthOfYear,
              _exitDate!.dayOfMonth,
            );

            if (entryDateTime.isAfter(exitDateTime)) {
              _exitDate = null;
            }
          }
        } else {
          // Convert DateTime to LocalDate
          _exitDate = LocalDate.dateTime(picked);
        }
      });
    }
  }

  void _saveStay() {
    if (_formKey.currentState!.validate()) {
      if (!_isCurrentlyInSchengen && _exitDate == null) {
        // Show error if exit date is needed but not provided
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an exit date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check that exit date is not before entry date (should be enforced by the date picker, but just in case)
      if (_exitDate != null && _exitDate! < _entryDate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exit date cannot be before entry date'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Create and save the new stay
      final stay = StayRecord(
        entryDate: _entryDate,
        exitDate: _isCurrentlyInSchengen ? null : _exitDate,
        notes: _notes.trim(),
      );

      Provider.of<StayProvider>(context, listen: false).addStay(stay);

      // Show success message and return to previous screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stay added successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Return true to indicate success
    }
  }
}
