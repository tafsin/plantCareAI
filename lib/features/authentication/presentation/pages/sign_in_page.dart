import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_ai/app/router/app_router.dart';
import 'package:plantcare_ai/features/authentication/presentation/bloc/sign_in_bloc.dart';
import 'package:plantcare_ai/features/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_ai/features/authentication/presentation/widgets/auth_page_frame.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({this.redirect, this.notice, super.key});

  final String? redirect;
  final String? notice;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<SignInBloc>().add(
      SignInSubmitted(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  void _inputChanged(String _) {
    context.read<SignInBloc>().add(const SignInInputChanged());
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Welcome back',
      subtitle: 'Sign in to care for your plants.',
      child: BlocBuilder<SignInBloc, SignInState>(
        builder: (context, state) {
          final isSubmitting = state is SignInSubmitting;
          return AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.notice case final String notice)
                    AuthInlineMessage(message: notice, isError: false),
                  TextFormField(
                    key: const ValueKey('sign-in-email'),
                    controller: _emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: AuthInputValidator.email,
                    onChanged: _inputChanged,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('sign-in-password'),
                    controller: _passwordController,
                    enabled: !isSubmitting,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: isSubmitting
                            ? null
                            : () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: AuthInputValidator.signInPassword,
                    onChanged: _inputChanged,
                    onFieldSubmitted: isSubmitting ? null : (_) => _submit(),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => context.go(
                              AppRoutes.forgotPasswordLocation(widget.redirect),
                            ),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (state case SignInFailure(:final message))
                    AuthInlineMessage(message: message, isError: true),
                  FilledButton(
                    key: const ValueKey('sign-in-submit'),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.go(
                            AppRoutes.registerLocation(widget.redirect),
                          ),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
