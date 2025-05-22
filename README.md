# Canadian Smoking History Generator Model (CSHGM)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![License: CC BY-NC-SA 4.0](https://img.shields.io/badge/License-CC%20BY--NC--SA%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## Overview

The Canadian Smoking History Generator Model (CSHGM) is an R implementation of the Age-Period-Cohort (APC) modelling approach to generate smoking histories based on Canadian Community Health Survey (CCHS) data. This project modernizes and extends the existing smoking history generation methodology developed in the Ontario SHGM study (2020) and the APC modelling approach pioneered by Holford.

## Key features

- Process CCHS data for smoking initiation and cessation analysis
- Implement Age-Period-Cohort (APC) modelling for smoking behaviors
- Generate complete smoking histories for simulated populations
- Validate against historical data
- Works in secure computing environments

## Installation

### Development version

To install the development version from GitHub:

```r
# Clone the repository
git clone https://github.com/cshgm/cshgm.git
cd cshgm

# Install renv package if you don't have it
install.packages("renv")

# Restore the project environment with renv
renv::restore()
```

This will set up a project-specific library with all the required package dependencies at the correct versions.

### Package version

```r
# Installation instructions will be added when the package is ready for distribution
```

## Usage example

```r
# Sample code for basic usage will be added as functionality is implemented
```

## Documentation

Comprehensive documentation is available in the `/docs` directory:

- **Tutorials**: Step-by-step guides to get started
- **How-to guides**: Practical instructions for specific tasks
- **Explanations**: Conceptual discussions of the methodology
- **Reference**: Technical details of functions and data

### Building the documentation website

This project uses [Quarto](https://quarto.org/) to generate a documentation website. To build the website:

1. **Install Quarto** if you haven't already: [Quarto Installation Guide](https://quarto.org/docs/get-started/)

2. **Preview the website** (with live updates as you edit):
   ```bash
   quarto preview
   ```

3. **Build the website** (generate static HTML files):
   ```bash
   quarto render
   ```
   This will create the website in the `_site` directory.

4. **GitHub Pages deployment**:
   The website is automatically deployed to GitHub Pages when changes are pushed to the main branch.

## Project structure

```
cshgm/
├── R/                   # R functions
├── data/                # Processed data objects 
├── docs/                # Documentation
│   ├── reference/       # Technical reference
│   ├── explanation/     # Conceptual explanations
│   ├── how-to/          # Task-oriented guides
│   └── tutorials/       # Learning-oriented tutorials
├── tests/               # Test files
├── config/              # Configuration files
├── resources/           # Project resources and reference materials
│   ├── cchs/            # CCHS documentation
│   ├── legacy-code/     # Original SAS implementation
│   ├── variable sheets/ # Variable definitions
│   └── worksheets/      # Working files
└── logs/                # Log files
```

## Development

This project is currently under active development. We welcome contributions from the community.

### Development workflow

1. **Set up the development environment**:
   ```r
   # Install renv package if you don't have it
   install.packages("renv")
   
   # Restore the project environment with renv
   renv::restore()
   ```

2. **Work on code changes**:
   - Add new functionality in the R/ directory
   - Add tests in the tests/testthat/ directory
   - Run tests: `testthat::test_dir("tests/testthat/")`

3. **Document your changes**:
   - Update or create documentation in docs/
   - Preview documentation: `quarto preview`

4. **Add new dependencies** (if needed):
   ```r
   renv::install("new-package")
   renv::snapshot()
   ```

### Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under:
- **Code**: [GNU General Public License v3.0](LICENSE)
- **Documentation and non-code assets**: [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-nc-sa/4.0/)

## Acknowledgments

- Dr. Ted Holford for the foundational APC methodology
- Statistics Canada for the CCHS data
- All contributors to the CSHGM Consortium
