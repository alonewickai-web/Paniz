import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

typedef JsonMap = Map<String, dynamic>;

class AdminIdentity {
  const AdminIdentity({
    required this.id,
    required this.fullName,
    required this.username,
    required this.phone,
    required this.role,
    this.avatarPath,
    this.permissions = const [],
    this.mustChangePassword = false,
  });

  final String id;
  final String fullName;
  final String username;
  final String phone;
  final String role;
  final String? avatarPath;
  final List<String> permissions;
  final bool mustChangePassword;
  bool can(String permission) =>
      role == 'owner' || role == 'admin' || permissions.contains(permission);

  factory AdminIdentity.fromJson(JsonMap json) => AdminIdentity(
    id: '${json['id'] ?? ''}',
    fullName: '${json['fullName'] ?? ''}',
    username: '${json['username'] ?? ''}',
    phone: '${json['phone'] ?? ''}',
    role: '${json['role'] ?? ''}',
    avatarPath: json['avatarPath'] as String?,
    permissions:
        (json['permissions'] as List? ?? const [])
            .map((item) => '$item')
            .toList(),
    mustChangePassword: json['mustChangePassword'] == true,
  );
}

class AdminApi {
  AdminApi() : _storage = const FlutterSecureStorage() {
    const apiUrl = String.fromEnvironment(
      'PANIZ_API_BASE_URL',
      defaultValue: 'https://api.panizstyle.ir/api/v1/',
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
  static const _notificationDeviceKey = 'paniz.admin.notification-device-id';
  static const _notificationChannel = MethodChannel(
    'paniz/admin-notifications',
  );

  Future<bool> hasSavedSession() async =>
      (await _storage.read(key: _tokenKey))?.isNotEmpty == true;

  Future<String> notificationDeviceId() async {
    final saved = await _storage.read(key: _notificationDeviceKey);
    if (saved != null && RegExp(r'^[0-9a-f-]{36}$').hasMatch(saved))
      return saved;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    await _storage.write(key: _notificationDeviceKey, value: id);
    return id;
  }

  static const _webBaseUrl = String.fromEnvironment(
    'PANIZ_WEB_BASE_URL',
    defaultValue: 'https://panizstyle.ir/',
  );

  static String imageUrl(String path) {
    final value = path.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('//')) return 'https:$value';

    final parsed = Uri.tryParse(value);
    if (parsed != null &&
        parsed.hasScheme &&
        (parsed.scheme == 'http' || parsed.scheme == 'https')) {
      return parsed.toString();
    }

    final normalized = value.replaceAll('\\', '/');
    if (normalized == '/uploads' ||
        normalized.startsWith('/uploads/') ||
        normalized == 'uploads' ||
        normalized.startsWith('uploads/')) {
      const apiUrl = String.fromEnvironment(
        'PANIZ_API_BASE_URL',
        defaultValue: 'https://api.panizstyle.ir/api/v1/',
      );
      return Uri.parse(apiUrl)
          .resolve(normalized.startsWith('/') ? normalized : '/$normalized')
          .toString();
    }
    return Uri.parse(_webBaseUrl).resolve(normalized).toString();
  }

  Future<AdminIdentity?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) return null;
    dio.options.headers['Authorization'] = 'Bearer $token';
    try {
      final response = await dio.get('admin/auth/me');
      return AdminIdentity.fromJson(_data(response));
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await clearSession();
        return null;
      }
      rethrow;
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
      await stopNotificationMonitoring();
      await dio.post('admin/auth/logout');
    } finally {
      await clearSession();
    }
  }

  Future<void> clearSession() async {
    await stopNotificationMonitoring();
    dio.options.headers.remove('Authorization');
    await _storage.delete(key: _tokenKey);
  }

  Future<JsonMap> dashboard() async => _data(await dio.get('admin/dashboard'));

  Future<JsonMap?> latestAppRelease() async {
    final body = _payload(await dio.get('admin/app-releases/latest'));
    return body is Map ? Map<String, dynamic>.from(body) : null;
  }

  Future<List<JsonMap>> appReleases() async =>
      _list(_payload(await dio.get('admin/app-releases')));

  Future<JsonMap> publishAppRelease(
    String path,
    String versionName,
    int versionCode,
    String notes,
    void Function(int, int) onProgress,
  ) async {
    return _data(
      await dio.post(
        'admin/app-releases',
        data: FormData.fromMap({
          'file': await MultipartFile.fromFile(
            path,
            filename: 'PANIZ-Admin.apk',
          ),
          'versionName': versionName,
          'versionCode': versionCode,
          'releaseNotes': notes,
        }),
        options: Options(
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: onProgress,
      ),
    );
  }

  Future<void> downloadAppRelease(
    JsonMap release,
    String destination,
    CancelToken cancelToken,
    void Function(int, int) onProgress,
  ) async {
    final base = Uri.parse(dio.options.baseUrl);
    final uri = base.resolve('${release['downloadPath']}');
    if (uri.scheme != 'https' ||
        uri.host != base.host ||
        uri.port != base.port) {
      throw const AdminApiException(
        'نشانی بروزرسانی باید از سرور امن همین فروشگاه باشد.',
      );
    }
    await dio.download(
      uri.toString(),
      destination,
      cancelToken: cancelToken,
      onReceiveProgress: onProgress,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
      deleteOnError: true,
    );
  }

  Future<JsonMap> staff({
    String query = '',
    String active = '',
    int page = 1,
  }) async => _envelope(
    await dio.get(
      'admin/staff',
      queryParameters: {
        'q': query,
        'active': active,
        'page': page,
        'pageSize': 30,
      },
    ),
  );
  Future<List<JsonMap>> permissionCatalog() async =>
      _list(_payload(await dio.get('admin/staff/permissions')));
  Future<JsonMap> saveStaff(JsonMap input, {String? id}) async => _data(
    id == null
        ? await dio.post('admin/staff', data: input)
        : await dio.patch('admin/staff/$id', data: input),
  );
  Future<JsonMap> staffDetail(String id) async =>
      _data(await dio.get('admin/staff/$id'));
  Future<JsonMap> resetStaffPassword(String id) async =>
      _data(await dio.post('admin/staff/$id/reset-password'));
  Future<JsonMap> auditLogs({
    int page = 1,
    String? adminId,
    String? entityType,
    String? result,
  }) async => _envelope(
    await dio.get(
      'admin/audit-logs',
      queryParameters: {
        'page': page,
        'pageSize': 30,
        if (adminId != null) 'adminId': adminId,
        if (entityType != null) 'entityType': entityType,
        if (result != null) 'result': result,
      },
    ),
  );
  Future<JsonMap> auditDetail(String id) async =>
      _data(await dio.get('admin/audit-logs/$id'));
  Future<JsonMap> updateProfile(JsonMap input) async =>
      _data(await dio.patch('admin/auth/profile', data: input));
  Future<JsonMap> uploadProfileAvatar(Uint8List bytes, String filename) async =>
      _data(
        await dio.post(
          'admin/auth/profile/avatar',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes(bytes, filename: filename),
          }),
        ),
      );
  Future<List<JsonMap>> productCategories() async =>
      _list(_payload(await dio.get('admin/product-categories')));
  Future<JsonMap> productDetail(String id) async =>
      _data(await dio.get('admin/products/detail/$id'));
  Future<JsonMap> orderDetail(String id) async =>
      _data(await dio.get('admin/orders/$id'));

  Future<JsonMap> adminNotifications() async =>
      _envelope(await dio.get('admin/notifications'));

  Future<JsonMap> notificationPreferences() async =>
      _data(await dio.get('admin/notifications/preferences'));

  Future<JsonMap> updateNotificationPreferences(JsonMap values) async =>
      _data(await dio.patch('admin/notifications/preferences', data: values));

  Future<JsonMap> registerNotificationDevice(String deviceId) async => _data(
    await dio.post(
      'admin/notifications/devices',
      data: {'deviceId': deviceId, 'deviceName': 'PANIZ Admin · Android'},
    ),
  );

  Future<List<JsonMap>> notificationDevices() async =>
      _list(_payload(await dio.get('admin/notifications/devices')));

  Future<void> revokeNotificationDevice(String deviceId) async {
    await dio.delete('admin/notifications/devices/$deviceId');
  }

  Future<bool> requestNotificationPermission() async =>
      await _notificationChannel.invokeMethod<bool>('requestPermission') ??
      false;

  Future<bool> hasNotificationPermission() async =>
      await _notificationChannel.invokeMethod<bool>('hasPermission') ?? false;

  Future<void> startNotificationMonitoring({
    required String deviceId,
    required bool soundEnabled,
    required bool vibrationEnabled,
  }) async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      throw const AdminApiException(
        'برای فعال‌کردن اعلان‌ها دوباره وارد حساب شوید.',
      );
    }
    await _notificationChannel.invokeMethod<void>('startMonitoring', {
      'apiBaseUrl': dio.options.baseUrl,
      'accessToken': token,
      'deviceId': deviceId,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
    });
  }

  Future<void> stopNotificationMonitoring() async {
    try {
      await _notificationChannel.invokeMethod<void>('stopMonitoring');
    } on PlatformException {
      /* Service may already be stopped. */
    } catch (_) {
      /* Native service may be unavailable on non-Android builds. */
    }
  }

  Future<void> resumeNotificationMonitoringIfEnabled() async {
    try {
      final preferences = await notificationPreferences();
      if (preferences['backgroundMonitoringEnabled'] != true ||
          !await hasNotificationPermission())
        return;
      final deviceId = await notificationDeviceId();
      await registerNotificationDevice(deviceId);
      await startNotificationMonitoring(
        deviceId: deviceId,
        soundEnabled: preferences['soundEnabled'] == true,
        vibrationEnabled: preferences['vibrationEnabled'] != false,
      );
    } catch (_) {
      // Do not block sign-in or session restoration on background notification setup.
    }
  }

  Future<void> markAdminNotificationRead(String id) async {
    await dio.patch('admin/notifications/$id/read');
  }

  Future<void> markAllAdminNotificationsRead() async {
    await dio.patch('admin/notifications/read-all');
  }

  Future<List<JsonMap>> adminChatContacts() async =>
      _list(_payload(await dio.get('admin/chat/contacts')));

  Future<List<JsonMap>> adminChatMessages(String contactId) async =>
      _list(_payload(await dio.get('admin/chat/messages/$contactId')));

  Future<JsonMap> sendAdminChat({
    String? recipientAdminId,
    required String body,
    bool broadcast = false,
  }) async => _data(
    await dio.post(
      'admin/chat/messages',
      data: {
        if (recipientAdminId != null) 'recipientAdminId': recipientAdminId,
        'body': body,
        'broadcast': broadcast,
      },
    ),
  );

  Future<JsonMap> siteVisitAnalytics() async =>
      _data(await dio.get('admin/analytics/site-visits'));

  Future<JsonMap> financeReport(String range) async => _data(
    await dio.get('admin/analytics/finance', queryParameters: {'range': range}),
  );

  Future<JsonMap> customers({
    int page = 1,
    String? query,
    String? city,
    String registration = 'any',
    String purchaseSort = 'none',
    String? productId,
  }) async => _data(
    await dio.get(
      'admin/customers',
      queryParameters: {
        'page': page,
        'pageSize': 50,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        'registration': registration,
        'purchaseSort': purchaseSort,
        if (productId != null && productId.isNotEmpty) 'productId': productId,
      },
    ),
  );

  Future<JsonMap> previewSmsAudience(JsonMap filters) async => _data(
    await dio.post('admin/sms-campaigns/preview', data: {'filters': filters}),
  );

  Future<List<JsonMap>> smsCampaigns() async =>
      _list(_payload(await dio.get('admin/sms-campaigns')));

  Future<JsonMap> createSmsCampaign(
    String title,
    String message,
    JsonMap filters,
  ) async => _data(
    await dio.post(
      'admin/sms-campaigns',
      data: {'title': title, 'message': message, 'filters': filters},
    ),
  );

  Future<JsonMap> sendSmsCampaign(String id) async =>
      _data(await dio.post('admin/sms-campaigns/$id/send'));

  String _campaignPath(String channel) =>
      channel == 'rubika' ? 'admin/rubika-campaigns' : 'admin/sms-campaigns';

  Future<JsonMap> previewCampaignAudience(
    String channel,
    JsonMap filters,
  ) async => _data(
    await dio.post(
      '${_campaignPath(channel)}/preview',
      data: {'filters': filters},
    ),
  );

  Future<List<JsonMap>> marketingCampaigns(String channel) async =>
      _list(_payload(await dio.get(_campaignPath(channel))));

  Future<JsonMap> createMarketingCampaign(
    String channel,
    String title,
    String message,
    JsonMap filters,
  ) async => _data(
    await dio.post(
      _campaignPath(channel),
      data: {'title': title, 'message': message, 'filters': filters},
    ),
  );

  Future<JsonMap> sendMarketingCampaign(String channel, String id) async =>
      _data(await dio.post('${_campaignPath(channel)}/$id/send'));

  Future<List<JsonMap>> coupons() async =>
      _list(_payload(await dio.get('admin/coupons')));

  Future<JsonMap> saveCoupon(JsonMap input, {String? id}) async => _data(
    id == null
        ? await dio.post('admin/coupons', data: input)
        : await dio.patch('admin/coupons/$id', data: input),
  );

  Future<List<JsonMap>> productOptions() async =>
      _list(_payload(await dio.get('admin/products/options')));

  Future<JsonMap> socialStatus() async =>
      _data(await dio.get('admin/social/status'));

  Future<List<JsonMap>> socialProducts() async =>
      _list(_payload(await dio.get('admin/social/products')));

  Future<List<JsonMap>> socialPosts() async =>
      _list(_payload(await dio.get('admin/social/posts')));

  Future<JsonMap> createSocialPost(JsonMap input) async =>
      _data(await dio.post('admin/social/posts', data: input));

  Future<JsonMap> approveSocialPost(String id) async =>
      _data(await dio.post('admin/social/posts/$id/approve'));

  Future<JsonMap> sendSocialPostNow(String id) async =>
      _data(await dio.post('admin/social/posts/$id/send-now'));

  Future<JsonMap> cancelSocialPost(String id) async =>
      _data(await dio.post('admin/social/posts/$id/cancel'));

  Future<JsonMap> operationsStatus() async =>
      _data(await dio.get('admin/operations/status'));

  Future<List<JsonMap>> backups() async =>
      _list(_payload(await dio.get('admin/operations/backups')));

  Future<JsonMap> createBackup() async =>
      _data(await dio.post('admin/operations/backups'));

  Future<JsonMap> storeConfiguration() async =>
      _data(await dio.get('admin/store'));

  Future<JsonMap> publicStoreConfiguration() async =>
      _data(await dio.get('storefront/config'));

  Future<JsonMap> updateShippingSettings(JsonMap settings) async =>
      _data(await dio.patch('admin/store/shipping', data: settings));

  Future<JsonMap> updateStoreLogo(String? logoPath) async =>
      _data(await dio.patch('admin/store/logo', data: {'logoPath': logoPath}));

  Future<List<JsonMap>> adminSupportTickets() async =>
      _list(_payload(await dio.get('admin/support/tickets')));

  Future<List<JsonMap>> adminReturns() async =>
      _list(_payload(await dio.get('admin/support/returns')));

  Future<JsonMap> replyToSupportTicket(
    String id,
    String body, {
    String? imagePath,
  }) async => _data(
    await dio.post(
      'admin/support/tickets/$id/messages',
      data: {'body': body, if (imagePath != null) 'imagePath': imagePath},
    ),
  );

  Future<JsonMap> updateReturnRequest(
    String id,
    String status,
    String note,
  ) async => _data(
    await dio.patch(
      'admin/support/returns/$id',
      data: {'status': status, 'adminNote': note},
    ),
  );

  Future<JsonMap> uploadSupportImage(Uint8List bytes, String filename) async =>
      _uploadTo('admin/support/uploads/image', bytes, filename);

  Future<JsonMap> uploadReturnReceipt(
    String id,
    Uint8List bytes,
    String filename,
  ) async => _uploadTo('admin/support/returns/$id/receipt', bytes, filename);

  Future<JsonMap> updateStoreTheme(String theme) async =>
      _data(await dio.patch('admin/store/theme', data: {'theme': theme}));

  Future<JsonMap> updateHomepageSection(String key, JsonMap changes) async =>
      _data(await dio.patch('admin/homepage-sections/$key', data: changes));

  Future<JsonMap> reorderHomepageSections(List<String> sectionKeys) async =>
      _data(
        await dio.patch(
          'admin/homepage-sections/reorder',
          data: {'sectionKeys': sectionKeys},
        ),
      );

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

  Future<void> archiveBanner(String id) async {
    await dio.delete('admin/banners/$id');
  }

  Future<JsonMap> restoreBanner(String id) async =>
      _data(await dio.post('admin/banners/$id/restore'));

  Future<List<JsonMap>> products({String? query}) async {
    Future<Response<dynamic>> fetchPage(int page) => dio.get(
      'admin/products',
      queryParameters: {
        'page': page,
        'pageSize': 100,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      },
    );

    final firstPage = await fetchPage(1);
    final products = _list(_payload(firstPage));
    final body = firstPage.data;
    final meta = body is Map ? body['meta'] : null;
    final totalPages =
        meta is Map ? int.tryParse('${meta['totalPages']}') ?? 1 : 1;
    if (totalPages <= 1) return products;

    final remainingPages = await Future.wait(
      List.generate(totalPages - 1, (index) => fetchPage(index + 2)),
    );
    return [
      ...products,
      for (final response in remainingPages) ..._list(_payload(response)),
    ];
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
    return uploadImage(bytes, filename);
  }

  Future<JsonMap> uploadImage(Uint8List bytes, String filename) async {
    return _uploadTo('admin/uploads/product-image', bytes, filename);
  }

  Future<JsonMap> _uploadTo(
    String path,
    Uint8List bytes,
    String filename,
  ) async {
    final extension = filename.split('.').last.toLowerCase();
    final mediaType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: DioMediaType.parse(mediaType),
      ),
    });
    return _data(await dio.post(path, data: form));
  }

  Future<JsonMap> addProductVariant(String productId, JsonMap input) async =>
      _data(await dio.post('admin/products/$productId/variants', data: input));

  Future<JsonMap> addProductImage(String productId, JsonMap input) async =>
      _data(await dio.post('admin/products/$productId/images', data: input));

  Future<JsonMap> updateProductImage(
    String productId,
    String imageId,
    JsonMap changes,
  ) async => _data(
    await dio.patch('admin/products/$productId/images/$imageId', data: changes),
  );

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

  static JsonMap _envelope(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map || !body.containsKey('data'))
      throw const AdminApiException('ساختار پاسخ API معتبر نیست.');
    return Map<String, dynamic>.from(body);
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
