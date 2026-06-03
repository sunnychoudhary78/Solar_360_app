import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class ProfileRepository {
  final Dio dio;

  ProfileRepository(this.dio);

  Future<String?> fetchProfilePictureFilename() async {
    try {
      final response = await dio.get('/employee-photo');
      final data = response.data;
      if (data is Map) {
        return data['profile_picture']?.toString();
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<String> uploadProfilePhoto(XFile file) async {
    final formData = FormData.fromMap({
      'photo': await MultipartFile.fromFile(
        file.path,
        filename: file.name,
      ),
    });

    final response = await dio.post(
      '/employee-photo/photo',
      data: formData,
    );

    final data = response.data;
    if (data is Map && data['filename'] != null) {
      return data['filename'].toString();
    }

    throw Exception('Upload failed');
  }
}
