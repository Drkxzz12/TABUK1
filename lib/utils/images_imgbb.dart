import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

Future<String?> uploadImageToImgbb(File imageFile) async {
  const apiKey = 'aae8c93b12878911b39dd9abc8c73376';
  final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
  final base64Image = base64Encode(await imageFile.readAsBytes());
  final response = await http.post(url, body: {'image': base64Image});
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['data']['url'] as String?;
  }
  return null;
}

Future<String?> uploadImageToImgbbWeb(String base64Image) async {
  const apiKey = 'aae8c93b12878911b39dd9abc8c73376';
  final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
  final response = await http.post(url, body: {'image': base64Image});
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['data']['url'] as String?;
  }
  return null;
}
