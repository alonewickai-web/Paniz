import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

typedef JsonMap = Map<String, dynamic>;

class AdminIdentity {
  const AdminIdentity({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.role,
  });

  final String id;
  final String fullName;
  final String username;
  final String phone;
  final String role;

  factory AdminIdentity.fromJson(JsonMap json) => AdminIdentity(
    id: '${json['id'] ?? ''}',
    fullName: '${json['fullName'] ?? ''}',
    username: '${json['username'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    role: '${json['role'] ?? ''}',
  );
}

class AdminApi {
  AdminApi() : _storage = const FlutterSecureStorage() {
    const apiUrl = String.fromEnvironment(
      'PANIZ_API_BASE_URL',
      defaultValue: 'http://10.0.2.2:4000/api/v1/',
    );
    dio = Dio(
      BaseOptions(
        baseUrl: apiUrl.endsWith('/') ? apiUrl : '$apiUrl/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      ),
    );
  }

  final FlutterSecureStorage _storage;
  late final Dio dio;
  static const _tokenKey = 'panizstyle.admin.access-token';
  static const _webBaseUrl = String.fromEnvironment(
    'PANIZ_WEB_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/',
  );

  static String imageUrl(String path) {
    if (path.startsWith('https://')) return path;
    if (path.startsWith('/uploads/')) {
      const apiUrl = String.fromEnvironment(
        'PANIZ_API_BASE_URL',
        defaultValue: 'http://10.0.2.2:4000/api/v1/',
      );
      return Uri.parse(apiUrl).resolve(path).toString();
    }
    return Uri.parse(_webBaseUrl).resolve(path).toString();
  }

  Future<AdminIdentity?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;
    dio.options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await dio.get('admin/auth/me');
      return AdminIdentity.fromJson(_data(response));
    } on DioException {
      await clearSession();
      return null;
    }
  }

  Future<AdminIdentity> login(String username, String password) async {
    final response = await dio.post(
      'admin/auth/login',
      data: {'username': username.trim(), 'password': password},
    );
    return _acceptSession(_data(response));
  }

  Future<JsonMap> updateCredentials({
    required String currentPassword,
    String? username,
    String? newPassword,
  }) async {
    final response = await dio.patch(
      'admin/auth/credentials',
      data: {
        'currentPassword': currentPassword,
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim(),
        if (newPassword != null && newPassword.isNotEmpty)
          'newPassword': newPassword,
      },
    );
    return _data(response);
  }

  Future<AdminIdentity> _acceptSession(JsonMap payload) async {
    final token = '${payload['accessToken'] ?? ''}';
    if (token.isEmpty)
      throw const AdminApiException('پاسخ ورود، توکن نشست نداشت.');
    await _storage.write(key: _tokenKey, value: token);
    dio.options.headers['Authorization'] = 'Bearer $token';
    final admin = Map<String, dynamic>.from(payload['admin'] as Map);
    return AdminIdentity.fromJson(admin);
  }

  Future<void> logout() async {
    try {
      await dio.post('admin/auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    dio.options.headers.remove('Authorization');
    await _storage.delete(key: _tokenKey);
  }

  Future<JsonMap> dashboard() async => _data(await dio.get('admin/dashboard'));

  Future<JsonMap> customers({int page = 1, String? query, String? city, String registration = 'any', String purchaseSort = 'none', String? productId}) async =>
      _data(await dio.get('admin/customers', queryParameters: {
        'page': page, 'pageSize': 50,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        'registration': registration,
        'purchaseSort': purchaseSort,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
      }));


  Future<JsonMap> previewSmsAudience(JsonMap filters) async =>
      _data(await dio.post('admin/sms-campaigns/preview', data: {'filters': filters}));

  Future<List<JsonMap>> smsCampaigns() async => _list(_payload(await dio.get('admin/sms-campaigns')));

  Future<JsonMap> createSmsCampaign(String title, String message, JsonMap filters) async =>
      _data(await dio.post('admin/sms-campaigns', data: {'title': title, 'message': message, 'filters': filters}));

  Future<JsonMap> sendSmsCampaign(String id) async =>
      _data(await dio.post('admin/sms-campaigns/$id/send'));

  String _campaignPath(String channel) => channel == 'rubika' ? 'admin/rubika-campaigns' : 'admin/sms-campaigns';

  Future<JsonMap> previewCampaignAudience(String channel, JsonMap filters) async =>
      _data(await dio.post('${_campaignPath(channel)}/preview', data: {'filters': filters}));

  Future<List<JsonMap>> marketingCampaigns(String channel) async =>
      _list(_payload(await dio.get(_campaignPath(channel))));

  Future<JsonMap> createMarketingCampaign(String channel, String title, String message, JsonMap filters) async =>
      _data(await dio.post(_campaignPath(channel), data: {'title': title, 'message': message, 'filters': filters}));

  Future<JsonMap> sendMarketingCampaign(String channel, String id) async =>
      _data(await dio.post('${_campaignPath(channel)}/$id/send'));

  Future<List<JsonMap>> coupons() async => _list(_payload(await dio.get('admin/coupons')));

  Future<JsonMap> saveCoupon(JsonMap input, {String? id}) async =>
      _data(id == null ? await dio.post('admin/coupons', data: input) : await dio.patch('admin/coupons/$id', data: input));

  Future<List<JsonMap>> productOptions() async => _list(_payload(await dio.get('admin/products/options')));

  Future<JsonMap> socialStatus() async => _data(await dio.get('admin/social/status'));

  Future<List<JsonMap>> socialPosts() async => _list(_payload(await dio.get('admin/social/posts')));

  Future<JsonMap> createSocialPost(JsonMap input) async =>
      _data(await dio.post('admin/social/posts', data: input));

  Future<JsonMap> operationsStatus() async => _data(await dio.get('admin/operations/status'));

  Future<List<JsonMap>> backups() async => _list(_payload(await dio.get('admin/operations/backups')));

  Future<JsonMap> createBackup() async => _data(await dio.post('admin/operations/backups'));

  Future<JsonMap> storeConfiguration() async =>
      _data(await dio.get('admin/store'));

  Future<JsonMap> updateStoreTheme(String theme) async =>
      _data(await dio.patch('admin/store/theme', data: {'theme': theme}));

  Future<JsonMap> updateHomepageSection(String key, JsonMap changes) async =>
      _data(await dio.patch('admin/homepage-sections/$key', data: changes));

  Future<JsonMap> reorderHomepageSections(List<String> sectionKeys) async =>
      _data(await dio.patch('admin/homepage-sections/reorder', data: {'sectionKeys': sectionKeys}));

  Future<JsonMap> createCategory(JsonMap input) async =>
      _data(await dio.post('admin/categories', data: input));

  Future<JsonMap> updateCategory(String id, JsonMap changes) async =>
      _data(await dio.patch('admin/categories/$id', data: changes));

  Future<void> archiveCategory(String id) async {
    await dio.delete('admin/categories/$id');
  }

  Future<JsonMap> createBanner(JsonMap input) async =>
      _data(await dio.post('admin/banners', data: input));

  Future<JsonMap> updateBanner(String id, JsonMap changes) async =>
      _data(await dio.patch('admin/banners/$id', data: changes));

  Future<void> deleteBanner(String id) async {
    await dio.delete('admin/banners/$id');
  }

  Future<List<JsonMap>> products({String? query}) async {
    final response = await dio.get(
      'admin/products',
      queryParameters: {
        'page': 1,
        'pageSize': 100,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    return _list(_payload(response));
  }

  Future<List<JsonMap>> categories() async {
    final response = await dio.get('categories');
    final roots = _list(_payload(response));
    final categories = <JsonMap>[];
    for (final root in roots) {
      categories.add(root);
      categories.addAll(_list(root['children']));
    }
    return categories;
  }

  Future<List<JsonMap>> orders({String? status}) async {
    final response = await dio.get(
      'admin/orders',
      queryParameters: {
        'page': 1,
        'pageSize': 50,
        if (status != null) 'status': status,
      },
    );
    return _list(_payload(response));
  }

  Future<JsonMap> updateOrderStatus(
    String id,
    String status, {
    String? note,
    String? trackingCode,
  }) async {
    final response = await dio.patch(
      'admin/orders/$id/status',
      data: {
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        if (trackingCode != null && trackingCode.trim().isNotEmpty)
          'trackingCode': trackingCode.trim(),
      },
    );
    return _data(response);
  }

  Future<JsonMap> adjustInventory(
    String variantId,
    int delta,
    String note,
  ) async {
    final response = await dio.patch(
      'admin/inventory/variants/$variantId',
      data: {'delta': delta, 'note': note.trim()},
    );
    return _data(response);
  }

  Future<JsonMap> updateVariant(String variantId, JsonMap changes) async {
    final response = await dio.patch(
      'admin/products/variants/$variantId',
      data: changes,
    );
    return _data(response);
  }

  Future<JsonMap> createProduct(JsonMap input) async =>
      _data(await dio.post('admin/products', data: input));

  Future<JsonMap> uploadProductImage(Uint8List bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    return _data(await dio.post('admin/uploads/product-image', data: form));
  }

  Future<JsonMap> addProductVariant(String productId, JsonMap input) async =>
      _data(await dio.post('admin/products/$productId/variants', data: input));

  Future<JsonMap> addProductImage(String productId, JsonMap input) async =>
      _data(await dio.post('admin/products/$productId/images', data: input));

  Future<void> deleteProductImage(String productId, String imageId) async {
    await dio.delete('admin/products/$productId/images/$imageId');
  }

  Future<JsonMap> updateProduct(String id, JsonMap changes) async =>
      _data(await dio.patch('admin/products/$id', data: changes));

  Future<void> archiveProduct(String id) async {
    await dio.delete('admin/products/$id');
  }

  static String friendlyError(Object error) {
    if (error is AdminApiException) return error.message;
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['error'] is Map) {
        final message = (body['error'] as Map)['message'];
        if (message is String) return message;
        if (message is List) return message.join('، ');
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'اتصال برقرار نشد. آدرس API و اتصال اینترنت را بررسی کن.';
      }
    }
    return 'درخواست انجام نشد؛ دوباره تلاش کن.';
  }

  static JsonMap _data(Response<dynamic> response) {
    final payload = _payload(response);
    if (payload is! Map)
      throw const AdminApiException('ساختار پاسخ API معتبر نیست.');
    return Map<String, dynamic>.from(payload);
  }

  static Object? _payload(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map || !body.containsKey('data'))
      throw const AdminApiException('ساختار پاسخ API معتبر نیست.');
    return body['data'];
  }

  static List<JsonMap> _list(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }
}

class AdminApiException implements Exception {
  const AdminApiException(this.message);
  final String message;
}
