# Documentation Build Guide

This directory contains the Sphinx-based documentation for the DERMATLAS tumour-only variant calling pipeline.

## Building the Documentation

### Prerequisites

Install the required Python packages:

```bash
pip install -r source/requirements.txt
```

Or if using a virtual environment:

```bash
python -m venv venv
source venv/bin/activate  # On Linux/Mac
# or
venv\Scripts\activate  # On Windows
pip install -r source/requirements.txt
```

### Build HTML Documentation

To build the HTML documentation:

```bash
make html
```

The generated documentation will be in `build/html/`. Open `build/html/index.html` in a web browser to view.

### Other Build Formats

Sphinx supports multiple output formats:

```bash
make help          # Show all available build targets
make latexpdf      # Build LaTeX and PDF documentation
make epub          # Build EPUB documentation
make clean         # Clean build directory
```

## Documentation Structure

```
docs/
├── Makefile                    # Build configuration for Linux/Mac
├── make.bat                    # Build configuration for Windows
├── README.md                   # This file
├── build/                      # Generated documentation (auto-created)
└── source/
    ├── conf.py                 # Sphinx configuration
    ├── index.rst               # Documentation homepage
    ├── requirements.txt        # Python dependencies
    ├── _static/                # Static files (CSS, images, etc.)
    ├── _templates/             # Custom templates
    └── user_docs/
        └── analysis_sop.md     # Main analysis SOP documentation
```

## Adding New Documentation

1. Create new Markdown (`.md`) or reStructuredText (`.rst`) files in `source/user_docs/`
2. Add the new file to the table of contents in `source/index.rst`
3. Rebuild the documentation with `make html`

### Example: Adding a new page

1. Create a new file: `source/user_docs/troubleshooting.md`
2. Edit `source/index.rst` to add:

```rst
.. toctree::
   :maxdepth: 2
   :caption: Contents:

   user_docs/analysis_sop.md
   user_docs/troubleshooting.md
```

3. Rebuild: `make html`

## Styling and Features

This documentation uses:

- **Theme**: Read the Docs theme (`sphinx_rtd_theme`)
- **Markdown support**: MyST Parser for enhanced Markdown
- **Code copy buttons**: `sphinx_copybutton` for easy code copying
- **Design components**: `sphinx_design` for callouts and cards

### Using callouts in Markdown

The MyST parser supports special syntax for notes, warnings, and tips:

```markdown
:::{note}
This is a note
:::

:::{important}
This is important information
:::

:::{warning}
This is a warning
:::
```

## Continuous Integration

The documentation can be automatically built in CI/CD pipelines. See `.gitlab-ci.yml` in the germline pipeline for an example configuration.

## More Information

- [Sphinx Documentation](https://www.sphinx-doc.org/)
- [MyST Parser Documentation](https://myst-parser.readthedocs.io/)
- [Read the Docs Theme](https://sphinx-rtd-theme.readthedocs.io/)
