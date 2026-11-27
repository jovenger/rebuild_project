"""Convertit les documents Markdown de StudioVoix en pages HTML autonomes pour l'installateur.

Sous-ensemble géré (celui des docs du projet) : titres, paragraphes, listes à puces imbriquées,
listes numérotées, tableaux, images, liens, gras, code en ligne, blocs de code.
Bibliothèque standard uniquement. Usage : python md_to_html.py entree.md sortie.html
"""

import html
import logging
import re
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] [md_to_html] %(message)s")
log = logging.getLogger("md_to_html")

CSS = """
:root { --fg:#1F2430; --muted:#5B6275; --accent:#6C4CF5; --bg:#FFFFFF; --soft:#F3F4F8; --line:#E2E5EE; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#E6E8EF; --muted:#A3A9B8; --accent:#9F8BFF; --bg:#14161C; --soft:#1E2129; --line:#2C3040; }
}
body { margin:0; background:var(--bg); color:var(--fg);
       font:16px/1.6 "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
main { max-width:980px; margin:0 auto; padding:32px 20px 64px; }
h1 { font-size:2em; margin:.2em 0 .6em; }
h2 { font-size:1.4em; margin:1.8em 0 .6em; padding-bottom:.25em; border-bottom:2px solid var(--line); }
h3 { font-size:1.15em; margin:1.4em 0 .4em; }
a { color:var(--accent); }
img { max-width:100%; height:auto; border-radius:14px; margin:8px 0; }
code { background:var(--soft); padding:.1em .35em; border-radius:5px; font-size:.92em; }
pre { background:var(--soft); padding:14px 16px; border-radius:10px; overflow-x:auto; }
pre code { background:none; padding:0; }
table { border-collapse:collapse; width:100%; margin:12px 0; }
th, td { border:1px solid var(--line); padding:8px 10px; text-align:left; vertical-align:top; }
th { background:var(--soft); }
li { margin:.2em 0; }
"""


def link(m: re.Match) -> str:
    """Lien Markdown -> HTML ; les liens vers des .md pointent vers les pages converties."""
    href = re.sub(r"\.md$", ".html", m.group(2))
    return '<a href="' + href + '">' + m.group(1) + "</a>"


def inline(text: str) -> str:
    """Mise en forme en ligne : code, images, liens (.md -> .html), gras."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            out.append("<code>" + html.escape(part[1:-1]) + "</code>")
            continue
        s = html.escape(part, quote=False)
        s = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", lambda m: f'<img src="{m.group(2)}" alt="{m.group(1)}">', s)
        s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", link, s)
        s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
        out.append(s)
    return "".join(out)


def convert(md: str) -> tuple[str, str]:
    lines = md.replace("\r\n", "\n").split("\n")
    body: list[str] = []
    title = "StudioVoix"
    para: list[str] = []
    list_stack: list[tuple[str, int]] = []   # (balise, indentation)
    i = 0

    def close_para():
        if para:
            body.append("<p>" + inline(" ".join(para)) + "</p>")
            para.clear()

    def close_lists(to_indent: int = -1):
        while list_stack and list_stack[-1][1] > to_indent:
            tag, _ = list_stack.pop()
            body.append(f"</li></{tag}>")

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            close_para(); close_lists()
            code = []
            i += 1
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i])
                i += 1
            body.append("<pre><code>" + html.escape("\n".join(code)) + "</code></pre>")
            i += 1
            continue

        if not stripped:
            close_para()
            i += 1
            continue

        m = re.match(r"^(#{1,3})\s+(.*)$", stripped)
        if m:
            close_para(); close_lists()
            level = len(m.group(1))
            if level == 1 and title == "StudioVoix":
                title = re.sub(r"[*`]", "", m.group(2))
            body.append(f"<h{level}>{inline(m.group(2))}</h{level}>")
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|[\s:|-]+\|\s*$", lines[i + 1]):
            close_para(); close_lists()
            cells = lambda row: [c.strip() for c in row.strip().strip("|").split("|")]
            body.append("<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in cells(line)) + "</tr></thead><tbody>")
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                body.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in cells(lines[i])) + "</tr>")
                i += 1
            body.append("</tbody></table>")
            continue

        m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", line)
        if m:
            close_para()
            indent = len(m.group(1))
            tag = "ol" if m.group(2)[0].isdigit() else "ul"
            if not list_stack or indent > list_stack[-1][1]:
                body.append(f"<{tag}><li>")
                list_stack.append((tag, indent))
            else:
                close_lists(indent)
                if list_stack and list_stack[-1][1] == indent:
                    body.append("</li><li>")
                else:
                    body.append(f"<{tag}><li>")
                    list_stack.append((tag, indent))
            item = [m.group(3)]
            # Lignes de continuation (indentées, sans nouvelle puce).
            while i + 1 < len(lines) and lines[i + 1].strip() and not re.match(r"^\s*([-*]|\d+\.)\s+", lines[i + 1]) \
                    and lines[i + 1].startswith(" " * (indent + 2)):
                i += 1
                item.append(lines[i].strip())
            body.append(inline(" ".join(item)))
            i += 1
            continue

        if list_stack and not line.startswith(" "):
            close_lists()
        para.append(stripped)
        i += 1

    close_para(); close_lists()
    return title, "\n".join(body)


def main() -> int:
    if len(sys.argv) != 3:
        log.error("usage : md_to_html.py entree.md sortie.html")
        return 2
    src, dst = Path(sys.argv[1]), Path(sys.argv[2])
    if not src.is_file():
        log.error("fichier introuvable : %s", src)
        return 1
    try:
        md = src.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        log.error("lecture impossible de %s : %s", src, e)
        return 1
    title, body = convert(md)
    page = (f'<!doctype html>\n<html lang="fr"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1">'
            f"<title>{html.escape(title)}</title><style>{CSS}</style></head>"
            f"<body><main>\n{body}\n</main></body></html>\n")
    try:
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(page, encoding="utf-8")
    except OSError as e:
        log.error("écriture impossible de %s : %s", dst, e)
        return 1
    log.info("%s -> %s (%d octets)", src, dst, len(page.encode("utf-8")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
