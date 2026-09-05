import 'package:plantcare_shared/errors.dart';
import 'package:test/test.dart';

void main() {
  test('generic errors retain type-and-message equality', () {
    expect(const UnexpectedAppError(), const UnexpectedAppError());
    expect(
      const UnexpectedAppError('Custom message'),
      const UnexpectedAppError('Custom message'),
    );
    expect(
      const ValidationAppError('Invalid value'),
      const ValidationAppError('Invalid value'),
    );
    expect(
      const UnexpectedAppError('Same message'),
      isNot(const ValidationAppError('Same message')),
    );
  });

  test('unexpected errors retain their safe default message', () {
    expect(
      const UnexpectedAppError().message,
      'Something went wrong. Please try again.',
    );
  });
}
