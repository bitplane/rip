# Shrinking giant PDF files from document scanners

Some PDFs contain only images, and while it's nice to make perfect backups of
these files, uploading a terrabyte to archive.org at 200kb/sec is a bronchitis
that nobody got time for.

The scripts in here will replace an image PDF with a TAR full of webp files, you
can (and should) adjust the number of threads, image size and quality by editing
the first couple of lines in `shrink.pdf`, which have been tuned for a specific
archival project.

* [🎥 cast](https://asciinema.org/a/718033) [💾](shrink_pdf.cast)
