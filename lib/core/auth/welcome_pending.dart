/// Whether to show the one-shot welcome dialog after [applyTokens].
///
/// True for brand-new accounts (`isNewUser`) and for any auth that used the
/// signup screen flow (`authAction == 'signup'`), including Google on an
/// existing account from that screen.
bool shouldPendingWelcome({
  required bool isNewUser,
  required String authAction,
}) {
  return isNewUser || authAction == 'signup';
}
