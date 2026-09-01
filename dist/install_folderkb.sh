#!/usr/bin/env bash
set -e

# Installer script to create a folderkb.toolpkg from repository files
# Usage: sh install_folderkb.sh
# This will create folderkb.toolpkg in the current directory (requires zip)

OUTDIR="folderkb_toolpkg_tmp"
PKGNAME="folderkb.toolpkg"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"/demo
mkdir -p "$OUTDIR"/docs

cat > "$OUTDIR"/README.md <<'README'
# FolderKB - 文件夹知识库

将手机本地文件夹挂载为 Operit AI 的知识库，支持 Markdown 智能分块、语义搜索、自动上下文注入和多级缓存。专为 Obsidian 笔记库优化。

(本 README 来自仓库，打包为 plugin 用于在 Operit 中安装)

## 说明

将本插件文件夹压缩为 single-file `.toolpkg` 后可以在 Operit 的本地安装中使用。
README

cat > "$OUTDIR"/demo/demo.py <<'PY'
"""
Demo for FolderKB (operit-AI- plugin)

This script demonstrates local Markdown splitting (by headings) and a simple keyword search.
It is intended as a runnable example you can adapt to call Operit AI tools (kb_reindex, kb_search, etc.).

Usage:
  python demo/demo.py /path/to/your/obsidian/vault "搜索关键字"

This script does not require external dependencies.
"""
import os
import re
import sys
from typing import List, Tuple

HEADING_RE = re.compile(r'^(#{1,6})\s+(.*)')


def split_markdown_by_headings(text: str, max_chunk_chars: int = 800) -> List[Tuple[str, str]]:
    """Split markdown into chunks by headings.

    Returns a list of (title, content) tuples. If a section is very long, it will be further chunked.
    """
    lines = text.splitlines()
    chunks = []
    cur_title = "(root)"
    cur_lines = []

    def push_current():
        if not cur_lines:
            return
        body = "\n".join(cur_lines).strip()
        if not body:
            return
        # chunk long bodies
        if len(body) <= max_chunk_chars:
            chunks.append((cur_title, body))
        else:
            # naive chunking by characters
            i = 0
            while i < len(body):
                part = body[i:i+max_chunk_chars]
                chunks.append((cur_title + ' (part)', part))
                i += max_chunk_chars

    for line in lines:
        m = HEADING_RE.match(line)
        if m:
            # new heading
            push_current()
            cur_title = m.group(2).strip()
            cur_lines = []
        else:
            cur_lines.append(line)
    push_current()
    return chunks


def iter_markdown_files(folder: str):
    for root, dirs, files in os.walk(folder):
        # skip Obsidian special folders
        skip = {'.obsidian', '.trash'}
        dirs[:] = [d for d in dirs if d not in skip]
        for f in files:
            if f.lower().endswith('.md'):
                yield os.path.join(root, f)


def build_index(folder: str, max_chunk_chars: int = 800):
    index = []  # list of dicts: {path, title, chunk, text_lower}
    for path in iter_markdown_files(folder):
        try:
            with open(path, 'r', encoding='utf-8') as fh:
                text = fh.read()
        except Exception as e:
            print(f"skip {path}: {e}")
            continue
        chunks = split_markdown_by_headings(text, max_chunk_chars=max_chunk_chars)
        for title, chunk in chunks:
            index.append({
                'path': os.path.relpath(path, folder),
                'title': title,
                'chunk': chunk,
                'text_lower': chunk.lower(),
            })
    return index


def simple_search(index, query: str, limit: int = 5):
    q = query.lower()
    # naive scoring: occurrences in title and body
    scored = []
    for item in index:
        score = 0
        if q in item['title'].lower():
            score += 10
        score += item['text_lower'].count(q)
        if score > 0:
            scored.append((score, item))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [it for _, it in scored[:limit]]


def print_results(results):
    for i, it in enumerate(results, 1):
        print(f"=== RESULT {i} — {it['path']} — {it['title']} ===")
        preview = it['chunk'][:1000].strip()
        print(preview)
        print('\n')


def main():
    if len(sys.argv) < 3:
        print('Usage: python demo/demo.py /path/to/obsidian "查询关键词"')
        sys.exit(1)
    folder = sys.argv[1]
    query = sys.argv[2]
    if not os.path.isdir(folder):
        print('folder not found:', folder)
        sys.exit(1)
    print('Indexing...')
    index = build_index(folder)
    print(f'Indexed {len(index)} chunks from markdown files.')
    print('Searching...')
    results = simple_search(index, query)
    print_results(results)
    print('Done.')


if __name__ == '__main__':
    main()
PY

cat > "$OUTDIR"/docs/index.md <<'MD'
# FolderKB - 项目主页

本页面为 FolderKB 插件的简要说明，你可以把它用作 GitHub Pages 的站点（Settings -> Pages -> Source -> Deploy from `main` branch `/docs` folder）。

## 简介

FolderKB 将手机本地文件夹挂载为 Operit AI 的知识库，专为 Obsidian 优化，支持 Markdown 智能分块、语义检索、自动注入与多级缓存。

MD

# copy license if exists
if [ -f LICENSE ]; then
  cp LICENSE "$OUTDIR"/
fi

# create the single-file package as a zip
if command -v zip >/dev/null 2>&1; then
  (cd "$OUTDIR" && zip -r ../"$PKGNAME" .) >/dev/null
  echo "Created $PKGNAME"
else
  echo "zip not found. Creating uncompressed directory package at $OUTDIR (not zipped)."
  echo "You can manually zip the $OUTDIR folder to create $PKGNAME."
fi

echo "Package is in: ${PKGNAME} (or folder ${OUTDIR})"

echo "To clean up temporary files, remove $OUTDIR"
