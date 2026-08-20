#!/usr/bin/env -S bash
#
# Regenera o glifo de marca (U+EC33, nome "hydra") dentro de
# Assets/Fonts/tabler/hydra-tabler-icons.ttf a partir da arte em
# Assets/Brand/hydra-mark.png.
#
# O traço vem do canal alfa da arte (linhas do emblema), então o glifo é
# line-art monocromática que a NIcon pode tintar como qualquer outro ícone.
# A arte tem detalhe demais para ler abaixo de ~24px — isso é limite da arte,
# não do traçado; qualquer fechamento morfológico que "simplifique" vira borrão
# (testado com Close Disk:4/8/14).
#
# Dependências: potrace, python-fonttools, imagemagick.
# Uso: Scripts/dev/brand-glyph.sh [PNG_DE_ORIGEM]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="${1:-$REPO_DIR/Assets/Brand/hydra-mark.png}"
TTF="$REPO_DIR/Assets/Fonts/tabler/hydra-tabler-icons.ttf"

for bin in potrace magick; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "$bin não encontrado no PATH." >&2
    exit 1
  }
done
python3 -c 'import fontTools' 2>/dev/null || {
  echo "python-fonttools não encontrado." >&2
  exit 1
}

WORK="$(mktemp -d /tmp/hydra-glyph.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# Máscara: alfa da arte, 1000px (upem da fonte), 1 = tinta.
magick "$SRC" -trim +repage -alpha extract -resize 1000x1000 -threshold 50% -negate "$WORK/mark.pbm"

# -t 30 descarta cisco; -a/-O suavizam sem apagar as pontas do emblema.
potrace -s -o "$WORK/mark.svg" --flat -t 30 -a 1.0 -O 0.6 "$WORK/mark.pbm"

python3 "$REPO_DIR/Scripts/dev/brand-glyph-install.py" "$WORK/mark.svg" "$TTF"

echo "Confira o resultado nos tamanhos reais de barra:"
echo "  magick -background '#101014' -fill '#e6e6ea' -font $TTF -pointsize 22 label:\$'\\uec33' /tmp/glyph22.png"
