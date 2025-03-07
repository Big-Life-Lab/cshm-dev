# Package Management with renv

This directory contains [renv](https://rstudio.github.io/renv/) configuration files for the CSHGM project. The `renv` package helps manage R package dependencies in a project-specific manner.

## Structure

- **renv.lock**: Records all package dependencies and their versions
- **activate.R**: Script to activate renv for this project
- **library/**: Contains installed packages (not tracked in git)

## Usage

To restore the project environment:

```r
renv::restore()
```

To add new packages:

```r
# Install a package
renv::install("packagename")

# Record the dependency in the lockfile
renv::snapshot()
```

## Benefits

- **Reproducibility**: Ensures consistent package versions across different environments
- **Isolation**: Project dependencies are isolated from your global R library
- **Documentation**: Explicitly records all dependencies
- **Portability**: Makes deployment in secure environments more reliable