#!/usr/bin/env python3
"""Prepare public normative text; strip Notion transport metadata and internal links."""
import argparse
from pathlib import Path
import re


def sanitize(text):
    if '<content>' in text:
        text = text.split('<content>', 1)[1].rsplit('</content>', 1)[0]
    text = re.sub(r'\s+discussion-urls="[^"]*"', '', text)
    # A self-closing internal mention has no visible text; keep a placeholder so its label isn't left dangling.
    text = re.sub(r'<(?:mention|page)\s+[^>]*(?:app\.notion\.com|notion\.so)[^>]*/>', '[internal reference omitted]', text)
    text = re.sub(r'<(?:mention|page)\s+[^>]*(?:app\.notion\.com|notion\.so)[^>]*>', '', text)
    text = re.sub(r'</(?:mention|page)>', '', text)
    text = re.sub(r'\[([^\]]+)\]\(https://(?:app\.notion\.com|[^/]*notion\.so)/[^)]+\)', r'\1', text)
    text = re.sub(r'https://(?:app\.notion\.com|[^/]*notion\.so)/[^\s<>"\)]+', '[internal reference omitted]', text)
    return text.strip()+'\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(sanitize(args.input.read_text()))


if __name__ == '__main__':
    main()
