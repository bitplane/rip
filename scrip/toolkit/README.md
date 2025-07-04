# Toolkit Scripts

Standalone utilities for archive management and PDF processing. These scripts are independent of the main rip library functions.

## Scripts

### `quarantine_bad_pdfs.sh`
Finds corrupted PDF files for Internet Archive upload preparation. IA checks PDFs for syntax errors, so this script quickly identifies and quarantines problematic files by renaming them with `.broken` extension and compressing with xz.

### `tar_leaf_dirs.sh`
Archives leaf directories (those with no subdirectories) containing specific file types into tar files. Designed for archive.org preparation with support for:
- Paths with spaces, parentheses, and special characters
- Parallel processing
- Verification before deletion
- Dry-run mode

**Usage:**
```bash
./tar_leaf_dirs.sh --ext pdf --dry-run /path/to/data
./tar_leaf_dirs.sh --ext pdf,jpg --parallel 8 /path/to/data
```

### `shrink-pdf/`
PDF size reduction toolkit that converts PDFs to WebP images and archives them. Can reduce file sizes by 15-20x but is computationally intensive (saturated a 256-core box):

- **`shrink_pdf.sh`** - Converts individual PDF pages to WebP images and packages in tar format
- **`shrink_dir.sh`** - Batch processes all PDFs in a directory with parallel job control

Useful for massive PDF collections where storage space is critical and some quality loss is acceptable.

## Notes

All scripts handle edge cases like special characters in filenames and provide logging for archive management workflows.