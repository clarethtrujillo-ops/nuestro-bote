import 'package:flutter/services.dart';

class ClipboardService {
  const ClipboardService();

  Future<void> copy(String value) {
    return Clipboard.setData(ClipboardData(text: value));
  }

  Future<String?> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }
}
