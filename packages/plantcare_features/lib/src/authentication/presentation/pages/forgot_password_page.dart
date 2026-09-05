import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:plantcare_features/src/authentication/presentation/bloc/password_reset_bloc.dart';
import 'package:plantcare_features/src/authentication/presentation/validation/auth_input_validator.dart';
import 'package:plantcare_features/src/authentication/presentation/widgets/auth_page_frame.dart';
import 'package:plantcare_features/src/navigation/app_routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({this.redirect, super.key});

  final String? redirect;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    context.read<PasswordResetBloc>().add(
      PasswordResetSubmitted(_emailController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      title: 'Reset your password',
      subtitle: 'We’ll email instructions if an account exists.',
      child: BlocListener<PasswordResetBloc, PasswordResetState>(
        listener: (context, state) {
          if (state is PasswordResetSuccess) {
            context.go(
              AppRoutes.signInLocation(widget.redirect),
              extra: passwordResetSuccessMessage,
            );
          }
        },
        child: BlocBuilder<PasswordResetBloc, PasswordResetState>(
          builder: (context, state) {
            final isSubmitting = state is PasswordResetSubmitting;
            return Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const ValueKey('reset-email'),
                    controller: _emailController,
                    enabled: !isSubmitting,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: AuthInputValidator.email,
                    onChanged: (_) => context.read<PasswordResetBloc>().add(
                      const PasswordResetInputChanged(),
                    ),
                    onFieldSubmitted: isSubmitting ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: 20),
                  if (state case PasswordResetFailure(:final message))
                    AuthInlineMessage(message: message, isError: true),
                  FilledButton(
                    key: const ValueKey('reset-submit'),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Send reset link'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => context.go(
                            AppRoutes.signInLocation(widget.redirect),
                          ),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
