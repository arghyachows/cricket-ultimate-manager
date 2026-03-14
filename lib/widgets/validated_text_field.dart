import 'package:flutter/material.dart';
import '../core/profanity_filter.dart';

/// A text field with built-in profanity filtering and validation
class ValidatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final int? maxLength;
  final int? maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final AutovalidateMode? autovalidateMode;
  final FocusNode? focusNode;
  final String? helperText;
  final bool checkProfanity;
  final int minLength;
  final int maxLengthForValidation;
  final String fieldName;
  final bool required;

  const ValidatedTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.autovalidateMode,
    this.focusNode,
    this.helperText,
    this.checkProfanity = true,
    this.minLength = 1,
    this.maxLengthForValidation = 100,
    this.fieldName = 'Text',
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        helperText: helperText,
        counterText: maxLength != null ? null : '',
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      maxLength: maxLength,
      maxLines: maxLines,
      minLines: minLines,
      textCapitalization: textCapitalization,
      enabled: enabled,
      autofocus: autofocus,
      autovalidateMode: autovalidateMode,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: (value) {
        // Custom validator takes precedence
        if (validator != null) {
          final error = validator!(value);
          if (error != null) return error;
        }

        // Profanity check
        if (checkProfanity) {
          return ProfanityFilter.validateText(
            value,
            fieldName: fieldName,
            minLength: minLength,
            maxLength: maxLengthForValidation,
            required: required,
          );
        }

        // Basic validation
        if (required && (value == null || value.isEmpty)) {
          return '$fieldName is required';
        }

        if (value != null && value.isNotEmpty) {
          if (value.length < minLength) {
            return '$fieldName must be at least $minLength characters';
          }
          if (value.length > maxLengthForValidation) {
            return '$fieldName must be less than $maxLengthForValidation characters';
          }
        }

        return null;
      },
    );
  }
}

/// Username text field with profanity checking
class UsernameTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  const UsernameTextField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: 'Username',
        labelText: 'Username',
        prefixIcon: Icon(Icons.person_outline),
        helperText: 'Letters, numbers, and underscores only',
      ),
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: ProfanityFilter.validateUsername,
    );
  }
}

/// Team name text field with profanity checking
class TeamNameTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  const TeamNameTextField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: 'Team Name',
        labelText: 'Team Name',
        prefixIcon: Icon(Icons.shield_outlined),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: ProfanityFilter.validateTeamName,
    );
  }
}

/// Display name text field with profanity checking
class DisplayNameTextField extends StatelessWidget {
  final TextEditingController controller;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;

  const DisplayNameTextField({
    super.key,
    required this.controller,
    this.textInputAction,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: const InputDecoration(
        hintText: 'Display Name',
        labelText: 'Display Name (Optional)',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      textCapitalization: TextCapitalization.words,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      focusNode: focusNode,
      autofocus: autofocus,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: ProfanityFilter.validateDisplayName,
    );
  }
}
