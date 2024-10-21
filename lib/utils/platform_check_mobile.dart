// lib/utils/platform_check_mobile.dart

import 'dart:io';

bool checkIsMobilePlatform() => Platform.isAndroid || Platform.isIOS;
