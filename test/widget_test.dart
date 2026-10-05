import 'package:dots_hr_pro/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server address becomes the API base', () {
    expect(Session.apiBase('hr.company.com'), 'https://hr.company.com/api');
    expect(Session.apiBase('192.168.1.10/dots-hr-pro/public/'), 'http://192.168.8.173/dots-hr-pro/public/api');
    expect(Session.apiBase('https://hr.company.com/api'), 'https://hr.company.com/api');
  });
}
