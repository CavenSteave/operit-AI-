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
