// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import '../../../models/event_model.dart';
import '../../../services/event_service.dart';
import '../../../utils/colors.dart';
import '../../../utils/images_imgbb.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class EventsManagementScreen extends StatefulWidget {
  const EventsManagementScreen({super.key});

  @override
  State<EventsManagementScreen> createState() => _EventsManagementScreenState();
}

class _EventsManagementScreenState extends State<EventsManagementScreen> {
  final Stream<List<Event>> _eventsStream = EventService.getEventsStream();

  Future<void> _addEvent(Event event) async {
    await EventService.addEvent(event);
    _showSnackBar('Event added successfully', AppColors.primaryTeal);
  }

  Future<void> _updateEvent(Event event) async {
    await EventService.updateEvent(event);
    _showSnackBar('Event updated successfully', AppColors.primaryTeal);
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirmed = await _showDeleteConfirmation();
    if (confirmed) {
      await EventService.deleteEvent(eventId);
      _showSnackBar('Event deleted successfully', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: const Text('Are you sure you want to delete this event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showEventDialog([Event? event]) {
    showDialog(
      context: context,
      builder: (context) => _EventDialog(
        event: event,
        onSave: event == null ? _addEvent : _updateEvent,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events Management', style: TextStyle(color: AppColors.textDark)),
        backgroundColor: AppColors.backgroundColor,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showEventDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Add Event',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: StreamBuilder<List<Event>>(
          stream: _eventsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading events'));
            }
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.event_busy, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('No events found'),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              itemBuilder: (context, index) => _EventCard(
                event: events[index],
                onEdit: () => _showEventDialog(events[index]),
                onDelete: () => _deleteEvent(events[index].eventId),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: event.images?.isNotEmpty == true
            ? CircleAvatar(backgroundImage: NetworkImage(event.images!.first))
            : const CircleAvatar(child: Icon(Icons.event)),
        title: Text(event.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text(DateFormat('MMM dd, yyyy').format(event.startdate)),
            if (event.location.isNotEmpty) Text(event.location),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _EventDialog extends StatefulWidget {
  final Event? event;
  final Function(Event) onSave;

  const _EventDialog({this.event, required this.onSave});

  @override
  State<_EventDialog> createState() => _EventDialogState();
}

class _EventDialogState extends State<_EventDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TextEditingController _durationController;
  late String _status;
  PlatformFile? _pickedFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _locationController = TextEditingController(text: widget.event?.location ?? '');
    _startDate = widget.event?.startdate ?? DateTime.now();
    _endDate = widget.event?.endstartDate ?? (widget.event?.startdate ?? DateTime.now());
    _durationController = TextEditingController(
      text: widget.event != null && widget.event!.endstartDate != null
        ? _calculateDurationString(widget.event!.startdate, widget.event!.endstartDate!)
        : '',
    );
    _status = widget.event?.status ?? 'active';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _startDate = date);
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate.isAfter(_startDate) ? _endDate : _startDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _endDate = date);
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    String? imageUrl;
    if (_pickedFile != null) {
      if (kIsWeb) {
        imageUrl = await uploadImageToImgbbWeb(base64Encode(_pickedFile!.bytes!));
      } else {
        imageUrl = await uploadImageToImgbb(File(_pickedFile!.path!));
      }
    }

    final event = Event(
      eventId: widget.event?.eventId ?? '',
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      startdate: _startDate,
      endstartDate: _endDate,
      createdAt: widget.event?.createdAt ?? DateTime.now(),
      status: _durationController.text.isNotEmpty ? _durationController.text : _status,
      images: imageUrl != null ? [imageUrl] : widget.event?.images ?? [],
    );

    widget.onSave(event);
    // ignore: use_build_context_synchronously
    Navigator.pop(context);
  }

  String _calculateDurationString(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    List<String> parts = [];
    if (days > 0) parts.add('$days day${days > 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours hour${hours > 1 ? 's' : ''}');
    if (minutes > 0) parts.add('$minutes min${minutes > 1 ? 's' : ''}');
    return parts.isEmpty ? '0 min' : parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildImagePreview(),
                ),
              ),
              SizedBox(height: 16),
              // Form fields
              _buildTextField(_titleController, 'Title', required: true),
              _buildTextField(_descriptionController, 'Description', maxLines: 3, required: true),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('Start: ${DateFormat('MMM dd, yyyy').format(_startDate)}'),
                onTap: _selectStartDate,
              ),
              ListTile(
                leading: Icon(Icons.calendar_today),
                title: Text('End:   ${DateFormat('MMM dd, yyyy').format(_endDate)}'),
                onTap: _selectEndDate,
              ),
              _buildTextField(_locationController, 'Location'),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: TextFormField(
                  controller: _durationController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () {
                    setState(() {
                      _durationController.text = _calculateDurationString(_startDate, _endDate);
                    });
                  },
                ),
              ),
              if (_isUploading) CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveEvent,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal, foregroundColor: Colors.white),
          child: Text(widget.event == null ? 'Add' : 'Update'),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_pickedFile != null) {
      return kIsWeb 
        ? Image.memory(_pickedFile!.bytes!, fit: BoxFit.cover)
        : Image.file(File(_pickedFile!.path!), fit: BoxFit.cover);
    }
    if (widget.event?.images?.isNotEmpty == true) {
      return Image.network(widget.event!.images!.first, fit: BoxFit.cover);
    }
    return Icon(Icons.add_a_photo, size: 40, color: Colors.black26);
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1, bool required = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
      ),
    );
  }
}