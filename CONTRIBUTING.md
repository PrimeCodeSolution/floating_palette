# Contributing to floating_palette

Thanks for your interest in contributing!

## Filing Issues

- Search existing issues before opening a new one.
- Include steps to reproduce, expected behavior, and macOS/Flutter versions.

## Development Setup

1. Clone the repo: `git clone https://github.com/PrimeCodeSolution/floating_palette.git`
2. Install dependencies for each package:
   ```bash
   cd floating_palette && flutter pub get
   cd ../floating_palette_annotations && dart pub get
   cd ../floating_palette_generator && dart pub get
   ```
3. Run code generation in the example app:
   ```bash
   cd floating_palette/example && dart run build_runner build
   ```

## Pull Requests

1. Fork the repo and create a feature branch from `main`.
2. Make your changes and ensure the code compiles without errors.
3. Run any existing tests: `flutter test` in the relevant package directory.
4. Open a PR with a clear description of what changed and why.

## Code Style

- Follow the lints configured in each package's `analysis_options.yaml`.
- Keep changes focused — one feature or fix per PR.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
