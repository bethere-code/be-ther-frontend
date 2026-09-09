// ponytail: session welcome trigger — fails if signup/new-user rules drift.
import 'welcome_pending.dart';

void main() {
  assert(shouldPendingWelcome(isNewUser: true, authAction: 'login'));
  assert(shouldPendingWelcome(isNewUser: false, authAction: 'signup'));
  assert(shouldPendingWelcome(isNewUser: true, authAction: 'signup'));
  assert(!shouldPendingWelcome(isNewUser: false, authAction: 'login'));
  print('welcome_pending.check: ok');
}
