import 'json_helpers.dart';

class UploadedImage {
  const UploadedImage({
    required this.imageId,
    required this.imageUrl,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
  });

  final int imageId;
  final String imageUrl;
  final String fileName;
  final int fileSize;
  final String mimeType;

  factory UploadedImage.fromJson(Map<String, dynamic> json) {
    return UploadedImage(
      imageId: asInt(json['image_id']),
      imageUrl: asString(json['image_url']),
      fileName: asString(json['file_name']),
      fileSize: asInt(json['file_size']),
      mimeType: asString(json['mime_type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'image_id': imageId,
      'image_url': imageUrl,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
    };
  }
}

