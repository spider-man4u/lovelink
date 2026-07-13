import 'package:cloudinary_public/cloudinary_public.dart';
import '../constants/api_config.dart';

class CloudinaryService {
  CloudinaryPublic? _cloudinary;

  bool get isAvailable => _cloudinary != null;

  CloudinaryService() {
    if (ApiConfig.useCloudinary) {
      _cloudinary = CloudinaryPublic(
        ApiConfig.cloudinaryCloudName,
        ApiConfig.cloudinaryUploadPreset,
      );
    }
  }

  Future<String?> uploadImage(String filePath) async {
    if (_cloudinary == null) return null;

    try {
      final response = await _cloudinary!.uploadFile(
        CloudinaryFile.fromFile(
          filePath,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }

  Future<String?> uploadImageFromBytes(
    List<int> bytes,
    String fileName,
  ) async {
    if (_cloudinary == null) return null;

    try {
      final response = await _cloudinary!.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      return null;
    }
  }
}
