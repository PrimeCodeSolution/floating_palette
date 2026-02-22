# Contributing to floating_palette

Thanks for your interest in contributing!

## Filing Issues

- Search existing issues before opening a new one.
- Include steps to reproduce, expected behavior, and macOS/Flutter versions.

## Development Setup

This repo uses [Dart workspaces](https://dart.dev/tools/pub/workspaces) — a single `pub get` at the root resolves all packages locally:

```bash
git clone https://github.com/PrimeCodeSolution/floating_palette.git
cd floating_palette
dart pub get
```

That's it. All three packages (`floating_palette_annotations`, `floating_palette_generator`, `floating_palette`) are resolved through the workspace. No extra tools needed.

To run code generation in the example app:

```bash
cd floating_palette/example && dart run build_runner build
```

## Pull Requests

1. Fork the repo and create a feature branch from `main`.
2. Make your changes and ensure `dart analyze` passes from the repo root.
3. Run tests in the relevant package directory (e.g. `dart test` or `flutter test`).
4. Open a PR with a clear description of what changed and why.

## Code Style

- Follow the lints configured in each package's `analysis_options.yaml`.
- Keep changes focused — one feature or fix per PR.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
