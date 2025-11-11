# Linting Guide

This project uses Flutter's built-in analyzer with comprehensive linting rules to maintain code quality.

## Running the Linter

### Analyze all files
```bash
flutter analyze
```

### Analyze specific file
```bash
flutter analyze lib/path/to/file.dart
```

### Analyze without info-level issues
```bash
flutter analyze --no-fatal-infos
```

## Linter Configuration

The linter is configured in `analysis_options.yaml` with:

- **Base rules**: `package:flutter_lints/flutter.yaml` (Flutter recommended lints)
- **Custom rules**: 100+ additional linting rules for:
  - Code style consistency
  - Error prevention
  - Best practices
  - Performance optimization

## Key Linting Rules

### Style Rules
- `prefer_single_quotes`: Use single quotes for strings
- `prefer_const_constructors`: Use const constructors when possible
- `prefer_final_fields`: Prefer final for fields
- `prefer_final_locals`: Prefer final for local variables

### Error Prevention
- `avoid_print`: Avoid using print statements (use logger instead)
- `avoid_unnecessary_containers`: Avoid unnecessary Container widgets
- `use_build_context_synchronously`: Don't use BuildContext after async gaps

### Best Practices
- `always_declare_return_types`: Always declare return types
- `prefer_null_aware_operators`: Use null-aware operators
- `prefer_is_empty`: Use `.isEmpty` instead of `.length == 0`
- `use_key_in_widget_constructors`: Use keys in widget constructors

## Excluded Files

The following file patterns are excluded from linting:
- `**/*.g.dart` (generated files)
- `**/*.freezed.dart` (freezed generated files)
- `**/*.mocks.dart` (mockito generated files)

## IDE Integration

Most IDEs (VS Code, Android Studio, IntelliJ) will automatically show lint issues:
- **Errors**: Red underlines
- **Warnings**: Yellow underlines
- **Info**: Blue underlines

## Fixing Lint Issues

### Auto-fix available issues
```bash
dart fix --apply
```

### Suppress specific lint
```dart
// ignore: lint_rule_name
code_here
```

### Suppress for entire file
```dart
// ignore_for_file: lint_rule_name
```

## Continuous Integration

Consider adding linting to your CI/CD pipeline:
```yaml
- name: Run linter
  run: flutter analyze
```

