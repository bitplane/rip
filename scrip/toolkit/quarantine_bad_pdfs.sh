#!/bin/bash

find . -name "*.pdf" -type f | sort | while read -r pdf; do
    if pdfinfo "$pdf" 2>&1 >/dev/null | grep -qi "error"; then
        echo "Quarantining: $pdf"
        mv "$pdf" "${pdf}.broken" && xz "${pdf}.broken"
    fi
done