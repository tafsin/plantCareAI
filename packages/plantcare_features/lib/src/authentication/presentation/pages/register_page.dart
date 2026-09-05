import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/register_bloc.dart';
import 'package:plantcare_features/src/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_features/src/authentication/presentation/widgets/auth_page_frame.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({this.redirect, super.key});

  final String? redirect;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  var _obscurePassword = true;
  var _obscureConfirmation = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<RegisterBloc>().add(
      RegisterSubmitted(
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmationController.text,
      ),
    );
  }

  void _inputChanged(String _) {
    context.read<RegisterBloc>().add(const RegisterInputChanged());
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Create your account',
      subtitle: 'Start building a healthier plant collection.',
      child: BlocBuilder<RegisterBloc, RegisterState>(
        builder: (context, state) {
          final isSubmitting = state is RegisterSubmitting;
          return AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('register-email'),
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
                    key: const ValueKey('register-password'),
                    controller: _passwordController,
                    enabled: !isSubmitting,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText:
                          'At least 6 characters, with a letter and number',
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
                    validator: AuthInputValidator.registrationPassword,
                    onChanged: (value) {
                      _inputChanged(value);
                      if (_confirmationController.text.isNotEmpty) {
                        _formKey.currentState?.validate();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('register-confirm-password'),
                    controller: _confirmationController,
                    enabled: !isSubmitting,
                    obscureText: _obscureConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _obscureConfirmation
                            ? 'Show confirmation password'
                            : 'Hide confirmation password',
                        onPressed: isSubmitting
                            ? null
                            : () => setState(
                                () => _obscureConfirmation =
                                    !_obscureConfirmation,
                              ),
                        icon: Icon(
                          _obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => AuthInputValidator.confirmation(
                      value,
                      _passwordController.text,
                    ),
                    onChanged: _inputChanged,
                    onFieldSubmitted: isSubmitting ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  if (state case RegisterFailure(:final message))
                    AuthInlineMessage(message: message, isError: true),
                  FilledButton(
                    key: const ValueKey('register-submit'),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.go(
                            AppRoutes.signInLocation(widget.redirect),
                          ),
                    child: const Text('Already have an account? Sign in'),
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
