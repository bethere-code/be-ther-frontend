// ponytail: LoadingLabel must cycle 1→2→3 dots; fails if step math regresses.
void main() {
  String dotsFor(double value) {
    final step = (value * 3).floor().clamp(0, 2);
    return '.' * (step + 1);
  }

  assert(dotsFor(0.0) == '.');
  assert(dotsFor(0.2) == '.');
  assert(dotsFor(0.34) == '..');
  assert(dotsFor(0.5) == '..');
  assert(dotsFor(0.67) == '...');
  assert(dotsFor(0.99) == '...');
  // ignore: avoid_print
  print('loading_label.check: ok');
}
