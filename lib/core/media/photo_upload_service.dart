import 'dart:io';
import 'package:dio/dio.dart';
import '../network/dio_client.dart';

class PhotoUploadService {
  static Future<String?> upload({
    required String localPath,
    required String parcelId,
    required String authorId,
    String? photoPointId,
    double? latitude,
    double? longitude,
    String? notes,
    int? year,
  }) async {
    try {
      if (!await File(localPath).exists()) return null;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(localPath),
        'parcelId': parcelId,
        'authorId': authorId,
        if (photoPointId != null) 'photoPointId': photoPointId,
        if (latitude != null) 'latitude': latitude.toString(),
        if (longitude != null) 'longitude': longitude.toString(),
        if (notes != null) 'notes': notes,
        if (year != null) 'year': year.toString(),
      });

      final response = await DioClient.instance.uploadFile('/media/upload', formData);
      if (response.statusCode == 201) {
        return response.data['data']['storageUrl'] as String?;
      }
    } catch (_) {}
    return null;
  }
}
