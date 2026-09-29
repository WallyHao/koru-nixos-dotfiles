# --- poppler-utils ---
# PDF tooling built on poppler; the one that matters here is pdftotext:
#   pdftotext -layout in.pdf out.txt
# `-layout` keeps the original visual layout, which is usually what you want.
# For scanned (image-only) PDFs nothing here helps; that needs OCR (tesseract).
{ pkgs, ... }:
{
  home.packages = [ pkgs.poppler-utils ];
}
