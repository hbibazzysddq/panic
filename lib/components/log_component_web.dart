import 'dart:html' as html;

Future<void> handleLogAction(String logContent) async {
  final bytes = html.Blob([logContent]);
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", "panic_button_log.txt")
    ..click();
  html.Url.revokeObjectUrl(url);
}
