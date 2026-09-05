import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantcare_app/app/theme/theme_bloc.dart';

void main() {
  test('uses the system theme by default', () {
    final bloc = ThemeBloc();
    addTearDown(bloc.close);

    expect(bloc.state, const ThemeState());
    expect(bloc.state.themeMode, ThemeMode.system);
  });

  blocTest<ThemeBloc, ThemeState>(
    'emits a selected theme mode',
    build: ThemeBloc.new,
    act: (bloc) => bloc.add(const ThemeModeChanged(ThemeMode.dark)),
    expect: () => [const ThemeState(themeMode: ThemeMode.dark)],
  );
}
