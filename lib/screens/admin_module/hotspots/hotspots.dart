import 'dart:io';
import 'dart:convert';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/services/hotspot_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/utils/images_imgbb.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class HotspotsManagementScreen extends StatefulWidget {
  const HotspotsManagementScreen({super.key});

  @override
  State<HotspotsManagementScreen> createState() => _HotspotsManagementScreenState();
}

class _HotspotsManagementScreenState extends State<HotspotsManagementScreen> {
  final Stream<List<Hotspot>> _hotspotsStream = HotspotService.getHotspotsStream();
  bool _showArchivedOnly = false;

  Future<void> _addHotspot(Hotspot hotspot) => HotspotService.addHotspot(hotspot);
  Future<void> _editHotspot(Hotspot hotspot) => HotspotService.updateHotspot(hotspot);
  Future<void> _archiveHotspot(String id) => HotspotService.archiveHotspot(id);
  Future<void> _restoreHotspot(String id) => HotspotService.restoreHotspot(id);

  void _showHotspotDialog([Hotspot? hotspot]) {
    showDialog(
      context: context,
      builder: (dialogContext) => _HotspotDialog(
        hotspot: hotspot,
        onSave: hotspot == null ? _addHotspot : _editHotspot,
      ),
    );
  }

  void _showArchiveConfirmDialog(Hotspot hotspot) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive Hotspot'),
        content: Text('Are you sure you want to archive "${hotspot.name}"? This will hide it from users but you can restore it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _archiveHotspot(hotspot.hotspotId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${hotspot.name} has been archived'),
                    backgroundColor: AppColors.primaryTeal,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _showRestoreConfirmDialog(Hotspot hotspot) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Restore Hotspot'),
        content: Text('Are you sure you want to restore "${hotspot.name}"? This will make it visible to users again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _restoreHotspot(hotspot.hotspotId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${hotspot.name} has been restored'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.hotspots, style: TextStyle(color: AppColors.textDark)),
        backgroundColor: AppColors.backgroundColor,
        iconTheme: IconThemeData(color: AppColors.textDark),
        elevation: 0,
        actions: [
          // Toggle button for showing archived hotspots
          IconButton(
            icon: Icon(_showArchivedOnly ? Icons.visibility : Icons.archive),
            onPressed: () {
              setState(() {
                _showArchivedOnly = !_showArchivedOnly;
              });
            },
            tooltip: _showArchivedOnly ? 'Show Active Hotspots' : 'Show Archived Hotspots',
          ),
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showHotspotDialog(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.backgroundGradient),
        child: Column(
          children: [
            // Status indicator
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    _showArchivedOnly ? Icons.archive : Icons.visibility,
                    color: _showArchivedOnly ? Colors.orange : Colors.green,
                  ),
                  SizedBox(width: 8),
                  Text(
                    _showArchivedOnly ? 'Showing Archived Hotspots' : 'Showing Active Hotspots',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _showArchivedOnly ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Hotspot>>(
                stream: _hotspotsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading hotspots'));
                  }
                  
                  final allHotspots = snapshot.data ?? [];
                  
                  // Filter hotspots based on archive status
                  final filteredHotspots = allHotspots.where((hotspot) {
                    final isArchived = hotspot.isArchived ?? false;
                    return _showArchivedOnly ? isArchived : !isArchived;
                  }).toList();

                  if (filteredHotspots.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showArchivedOnly ? Icons.archive : Icons.location_on,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _showArchivedOnly 
                              ? 'No archived hotspots found' 
                              : 'No active hotspots found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: filteredHotspots.length,
                    itemBuilder: (context, index) {
                      final hotspot = filteredHotspots[index];
                      final isArchived = hotspot.isArchived ?? false;
                      
                      return Card(
                        margin: EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            // Add subtle overlay for archived items
                            color: isArchived ? Colors.grey.withOpacity(0.1) : null,
                          ),
                          child: ListTile(
                            onTap: () => _showHotspotDialog(hotspot),
                            leading: Stack(
                              children: [
                                _buildHotspotImage(hotspot),
                                if (isArchived)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.archive,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              hotspot.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isArchived ? Colors.grey : null,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  hotspot.category,
                                  style: TextStyle(
                                    color: isArchived ? Colors.grey : AppColors.primaryTeal,
                                  ),
                                ),
                                Text(
                                  hotspot.formattedEntranceFee,
                                  style: TextStyle(
                                    color: isArchived ? Colors.grey : null,
                                  ),
                                ),
                                Text(
                                  '${hotspot.latitude?.toStringAsFixed(5) ?? 'N/A'}, ${hotspot.longitude?.toStringAsFixed(5) ?? 'N/A'}',
                                  style: TextStyle(
                                    color: isArchived ? Colors.grey : null,
                                  ),
                                ),
                                if (isArchived)
                                  Container(
                                    margin: EdgeInsets.only(top: 4),
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ARCHIVED',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: isArchived
                                ? IconButton(
                                    icon: Icon(Icons.restore, color: Colors.green),
                                    onPressed: () => _showRestoreConfirmDialog(hotspot),
                                    tooltip: 'Restore hotspot',
                                  )
                                : IconButton(
                                    icon: Icon(Icons.archive, color: Colors.orange),
                                    onPressed: () => _showArchiveConfirmDialog(hotspot),
                                    tooltip: 'Archive hotspot',
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHotspotImage(Hotspot hotspot) {
    final isArchived = hotspot.isArchived ?? false;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColorFiltered(
        colorFilter: isArchived 
          ? ColorFilter.mode(Colors.grey, BlendMode.saturation)
          : ColorFilter.mode(Colors.transparent, BlendMode.multiply),
        child: hotspot.images.isNotEmpty
            ? Image.network(
                hotspot.images.first,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              )
            : Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image,
                  color: Colors.black26,
                  size: 28,
                ),
              ),
      ),
    );
  }
}

class _HotspotDialog extends StatefulWidget {
  final Hotspot? hotspot;
  final Function(Hotspot) onSave;

  const _HotspotDialog({required this.onSave, this.hotspot});

  @override
  State<_HotspotDialog> createState() => _HotspotDialogState();
}

class _HotspotDialogState extends State<_HotspotDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  
  String _category = AppConstants.naturalAttraction;
  double _entranceFee = 0.0;
  bool _restroom = true;
  bool _foodAccess = true;
  bool _isUploading = false;
  
  PlatformFile? _pickedFile;
  String? _imageUrl;
  LatLng? _location;

  @override
  void initState() {
    super.initState();
    final h = widget.hotspot;
    
    // Initialize controllers
    final fields = ['name', 'description', 'operatingHours', 'contactInfo', 'localGuide', 
                   'transportation', 'safetyTips', 'suggestions', 'district', 'municipality'];
    
    for (String field in fields) {
      _controllers[field] = TextEditingController(text: _getInitialValue(field, h));
    }
    
    if (h != null) {
      _category = h.category;
      _entranceFee = h.entranceFee ?? 0.0;
      _restroom = h.restroom;
      _foodAccess = h.foodAccess;
      _location = (h.latitude != null && h.longitude != null) ? LatLng(h.latitude!, h.longitude!) : null;
      _imageUrl = h.images.isNotEmpty ? h.images.first : null;
    }
  }

  String _getInitialValue(String field, Hotspot? h) {
    if (h == null) return '';
    switch (field) {
      case 'name': return h.name;
      case 'description': return h.description;
      case 'operatingHours': return h.operatingHours;
      case 'contactInfo': return h.contactInfo;
      case 'localGuide': return h.localGuide ?? '';
      case 'transportation': return h.transportation.join(', ');
      case 'safetyTips': return h.safetyTips?.join(', ') ?? '';
      case 'suggestions': return h.suggestions?.join(', ') ?? '';
      case 'district': return h.district;
      case 'municipality': return h.municipality;
      default: return '';
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _imageUrl = null;
      });
    }
  }

  Future<void> _pickLocation() async {
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) => _LocationPicker(initialLocation: _location),
    );
    if (result != null) {
      setState(() => _location = result);
    }
  }

  Future<void> _saveHotspot() async {
    if (!_formKey.currentState!.validate() || _location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all fields and pick a location'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => _isUploading = true);
    
    String? imageUrl = _imageUrl;
    if (_pickedFile != null) {
      if (kIsWeb) {
        final base64 = _pickedFile!.bytes != null ? base64Encode(_pickedFile!.bytes!) : '';
        imageUrl = await uploadImageToImgbbWeb(base64);
      } else {
        imageUrl = await uploadImageToImgbb(File(_pickedFile!.path!));
      }
    }

    final hotspot = Hotspot(
      hotspotId: widget.hotspot?.hotspotId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _controllers['name']!.text,
      description: _controllers['description']!.text,
      category: _category,
      location: '',
      district: _controllers['district']!.text,
      municipality: _controllers['municipality']!.text,
      images: imageUrl != null ? [imageUrl] : [],
      transportation: _splitText(_controllers['transportation']!.text),
      operatingHours: _controllers['operatingHours']!.text,
      safetyTips: _splitText(_controllers['safetyTips']!.text),
      entranceFee: _entranceFee,
      contactInfo: _controllers['contactInfo']!.text,
      localGuide: _controllers['localGuide']!.text,
      restroom: _restroom,
      foodAccess: _foodAccess,
      suggestions: _splitText(_controllers['suggestions']!.text),
      createdAt: widget.hotspot?.createdAt ?? DateTime.now(),
      latitude: _location!.latitude,
      longitude: _location!.longitude,
      // Preserve the archive status when editing
      isArchived: widget.hotspot?.isArchived ?? false,
    );

    widget.onSave(hotspot);
    if (mounted) {
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hotspot saved successfully'), backgroundColor: AppColors.primaryTeal),
      );
    }
  }

  List<String> _splitText(String text) {
    return text.isEmpty ? [] : text.split(',').map((e) => e.trim()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.hotspot == null ? 'Add Hotspot' : 'Edit Hotspot'),
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
              _buildTextField('name', 'Hotspot Name', required: true),
              _buildDropdown(),
              _buildTextField('description', 'Description', maxLines: 2, required: true),
              _buildNumberField(),
              _buildTextField('operatingHours', 'Operating Hours', required: true),
              _buildTextField('contactInfo', 'Contact Info', required: true),
              _buildTextField('localGuide', 'Local Guide'),
              _buildTextField('transportation', 'Transportation (comma separated)'),
              _buildTextField('safetyTips', 'Safety Tips (comma separated)'),
              _buildTextField('suggestions', 'Suggestions (comma separated)'),
              _buildTextField('district', 'District', required: true),
              _buildTextField('municipality', 'Municipality', required: true),
              
              // Switches
              SwitchListTile(
                title: Text('Restroom'),
                value: _restroom,
                onChanged: (v) => setState(() => _restroom = v),
              ),
              SwitchListTile(
                title: Text('Food Access'),
                value: _foodAccess,
                onChanged: (v) => setState(() => _foodAccess = v),
              ),
              
              // Location picker
              Row(
                children: [
                  Expanded(
                    child: Text(_location == null ? 'No location selected' : 
                      'Lat: ${_location!.latitude.toStringAsFixed(5)}, Lng: ${_location!.longitude.toStringAsFixed(5)}'),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.map),
                    label: Text('Pick Location'),
                    onPressed: _pickLocation,
                  ),
                ],
              ),
              
              if (_isUploading) CircularProgressIndicator(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveHotspot,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal, foregroundColor: Colors.white),
          child: Text('Save'),
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
    if (_imageUrl != null) {
      return Image.network(_imageUrl!, fit: BoxFit.cover);
    }
    return Icon(Icons.add_a_photo, size: 40, color: Colors.black26);
  }

  Widget _buildTextField(String key, String label, {int maxLines = 1, bool required = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        controller: _controllers[key],
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: required ? (v) => v?.isEmpty == true ? 'Required' : null : null,
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: DropdownButtonFormField<String>(
        value: _category,
        decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
        items: AppConstants.hotspotCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _category = v!),
      ),
    );
  }

  Widget _buildNumberField() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: TextFormField(
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: 'Entrance Fee', border: OutlineInputBorder()),
        initialValue: _entranceFee.toString(),
        onChanged: (v) => _entranceFee = double.tryParse(v) ?? 0.0,
      ),
    );
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }
}

class _LocationPicker extends StatefulWidget {
  final LatLng? initialLocation;
  const _LocationPicker({this.initialLocation});

  @override
  State<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<_LocationPicker> {
  LatLng? _selectedLocation;
  final _bukidnonBounds = LatLngBounds(
    southwest: LatLng(7.5, 124.3),
    northeast: LatLng(8.9, 125.7),
  );

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pick Location (Bukidnon Only)'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialLocation ?? LatLng(8.1500, 125.1000),
            zoom: 10,
          ),
          markers: _selectedLocation != null ? {
            Marker(markerId: MarkerId('picked'), position: _selectedLocation!)
          } : {},
          onTap: (latLng) {
            if (_isInBounds(latLng)) {
              setState(() => _selectedLocation = latLng);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Select location within Bukidnon'), backgroundColor: Colors.red),
                );
              }
            }
          },
          cameraTargetBounds: CameraTargetBounds(_bukidnonBounds),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
        TextButton(
          onPressed: _selectedLocation != null ? () => Navigator.pop(context, _selectedLocation) : null,
          child: Text('Confirm'),
        ),
      ],
    );
  }

  bool _isInBounds(LatLng latLng) {
    return latLng.latitude >= _bukidnonBounds.southwest.latitude &&
           latLng.latitude <= _bukidnonBounds.northeast.latitude &&
           latLng.longitude >= _bukidnonBounds.southwest.longitude &&
           latLng.longitude <= _bukidnonBounds.northeast.longitude;
  }
}