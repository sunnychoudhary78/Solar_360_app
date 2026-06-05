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
        final value = data['profile_picture'] ??
            data['profilePicture'] ??
            data['filename'] ??
            data['photo'];

        if (value == null) return null;

        final clean = value.toString().trim();
        return clean.isEmpty ? null : clean;
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return null;
      if (e.response?.statusCode == 404) return null;
      return null;
    } catch (_) {
      return null;
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

    if (data is Map) {
      final value = data['filename'] ??
          data['profile_picture'] ??
          data['profilePicture'] ??
          data['photo'];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    throw Exception('Upload failed');
  }
}