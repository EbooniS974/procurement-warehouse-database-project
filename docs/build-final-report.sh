#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

rm -f \
  db-schema-summary.png db-schema-summary.pdf \
  er-overview.png er-overview.pdf \
  er-security.png er-security.pdf \
  er-procurement.png er-procurement.pdf \
  er-warehouse.png er-warehouse.pdf \
  er-diagram.png er-diagram.pdf \
  er-diagram-panel-1.png er-diagram-panel-1.pdf \
  er-diagram-panel-2.png er-diagram-panel-2.pdf \
  er-diagram-panel-3.png er-diagram-panel-3.pdf \
  er-diagram-panel-4.png er-diagram-panel-4.pdf \
  final-report.pdf

for name in db-schema-summary er-overview er-security er-procurement er-warehouse er-diagram; do
    dot -Tpng "${name}.dot" -o "${name}.png"
    dot -Tpdf "${name}.dot" -o "${name}.pdf"
done

python3 - <<'PY'
from pathlib import Path
from PIL import Image

root = Path(".")
image = Image.open(root / "er-diagram.png")
w, h = image.size

overlap_x = int(w * 0.08)
overlap_y = int(h * 0.08)
mid_x = w // 2
mid_y = h // 2

boxes = [
    (0, 0, min(w, mid_x + overlap_x), min(h, mid_y + overlap_y)),
    (max(0, mid_x - overlap_x), 0, w, min(h, mid_y + overlap_y)),
    (0, max(0, mid_y - overlap_y), min(w, mid_x + overlap_x), h),
    (max(0, mid_x - overlap_x), max(0, mid_y - overlap_y), w, h),
]

for index, box in enumerate(boxes, start=1):
    panel = image.crop(box)
    png_path = root / f"er-diagram-panel-{index}.png"
    pdf_path = root / f"er-diagram-panel-{index}.pdf"
    panel.save(png_path)
    panel.convert("RGB").save(pdf_path, resolution=300.0)
PY

pandoc \
  --metadata-file=report-metadata.yaml \
  project-report.md \
  -o final-report.pdf \
  --pdf-engine=xelatex
