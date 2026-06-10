# Contributing to CSHM

Thank you for your interest in contributing to the Canadian Smoking Histories Model (CSHM) project! This document provides guidelines for contributions to help maintain consistency and quality across the project.

## Code of Conduct

All contributors are expected to adhere to the project's code of conduct, which promotes a respectful and inclusive environment for collaboration.

## How to Contribute

There are many ways to contribute to the CSHM project:

1. **Report issues**: Submit bug reports or feature requests through the GitHub issue tracker.
2. **Suggest improvements**: Share ideas for enhancing the code, documentation, or workflow.
3. **Submit code**: Contribute code improvements via pull requests.
4. **Improve documentation**: Help make the documentation more comprehensive and clear.
5. **Test the software**: Report unexpected behavior or performance issues.

## Development Workflow

### 1. Fork the Repository

Start by forking the repository and creating a local clone of your fork:

```bash
git clone https://github.com/your-username/cshgm.git
cd cshgm

# Install renv if you don't have it
install.packages("renv")

# Set up the project environment with renv
renv::restore()
```

This will set up all the required package dependencies in a project-specific library.

### 2. Create a Branch

Create a branch for your changes:

```bash
git checkout -b your-branch-name
```

Use descriptive branch names that reflect the purpose of your changes:
- `feature/add-cessation-model`
- `fix/initiation-calculation-bug`
- `docs/improve-apc-explanation`

### 3. Make Your Changes

Follow these guidelines when making changes:

- Adhere to the code style guidelines in the project specifications
- Use clear, descriptive variable and function names
- Add comprehensive documentation for new functions
- Include tests for new functionality
- Follow Canadian spelling conventions

#### Package Management

When adding new package dependencies:

```r
# Install a new package with renv
renv::install("packagename")

# Update the renv.lock file to record the dependency
renv::snapshot()
```

Include the updated `renv.lock` file in your pull request so other contributors will get the same dependencies.

### 4. Test Your Changes

Before submitting a pull request, ensure that:

- All tests pass
- New functionality is tested
- Documentation is updated and complete

Run tests with:

```r
testthat::test_dir("tests/testthat/")
```

### 5. Update Documentation

If your changes require documentation updates:

1. Edit the appropriate `.qmd` files in the `docs/` directory
2. Preview your changes locally:
   ```bash
   quarto preview
   ```
3. Make sure your documentation changes render correctly before submitting your PR

#### Documentation Structure

- `docs/reference/`: Technical reference documentation
- `docs/how-to/`: Task-oriented guides
- `docs/explanation/`: Conceptual explanations
- `docs/tutorials/`: Learning-oriented tutorials

#### Writing Style

- Use sentence case for headings
- Follow Canadian spelling conventions
- Be clear, concise, and direct
- Use examples where appropriate

### 6. Submit a Pull Request

1. Push your changes to your fork:
   ```bash
   git push origin your-branch-name
   ```

2. Create a pull request from your branch to the main CSHM repository
3. Provide a clear title and description for your pull request, explaining:
   - What changes you've made
   - Why these changes are necessary
   - Any dependencies or potential issues

### 7. Code Review

All pull requests will be reviewed by project maintainers. Be prepared to:
- Answer questions about your implementation
- Make requested changes to meet project standards
- Be patient during the review process

## Styleguides

### Code Style

- Follow tidyverse design principles
- Use snake_case for function and variable names
- Include roxygen2 documentation for all functions
- Format code with the styler package

### Commit Messages

Write clear, concise commit messages that explain what the commit does and why:

```
Add smoking cessation function

Implements the processing for smoking cessation data based on the APC model.
Function extracts cessation age and calculates cessation probabilities.
```

## Licence

By contributing to CSHM, you agree that your contributions will be licensed under the [MIT License](LICENSE).

## Questions?

If you have questions about contributing, please open an issue on GitHub for clarification.