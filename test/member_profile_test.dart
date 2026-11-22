import 'package:flutter_test/flutter_test.dart';
import 'package:ssiteapp/services/member_profile.dart';

void main() {
  test(
    'profile uses canonical account and its current workspace permission',
    () {
      final member = MemberProfile.fromCms({
        'name': 'Ari',
        'email': 'ari@mcc.edu.ph',
        'can_access_workspace': true,
      });
      expect(member.name, 'Ari');
      expect(member.canAccessWorkspace, isTrue);
      expect(MemberProfile.fromCms({}).canAccessWorkspace, isFalse);
    },
  );
}
