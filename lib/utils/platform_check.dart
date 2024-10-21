// lib/utils/platform_check.dart

import 'platform_check_stub.dart'
    if (dart.library.io) 'platform_check_mobile.dart';

bool get isMobilePlatform => checkIsMobilePlatform();
