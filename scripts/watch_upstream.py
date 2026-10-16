"""Report upstream changes; never execute fetched content or invoke a coding agent."""
import hashlib
import json
import os
import re
import urllib.request
from html.parser import HTMLParser

TITLE = "[maintenance] Upstream compatibility watch"
SOURCES = {
    "Firebase Apple SDK release": "https://api.github.com/repos/firebase/firebase-ios-sdk/releases/latest",
    "XcodeGen release": "https://api.github.com/repos/yonaskolb/XcodeGen/releases/latest",
    "Vertex model lifecycle": "https://cloud.google.com/vertex-ai/generative-ai/docs/learn/model-versions",
    "Apple upcoming requirements": "https://developer.apple.com/news/upcoming-requirements/",
}

class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip = 0
        self.parts = []
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'): self.skip += 1
    def handle_endtag(self, tag):
        if tag in ('script', 'style'): self.skip = max(0, self.skip - 1)
    def handle_data(self, data):
        if not self.skip: self.parts.append(data)

def digest(body, is_json=False):
    if is_json:
        value = json.loads(body)
        normalized = json.dumps({k: value.get(k) for k in ('tag_name', 'published_at', 'body')}, sort_keys=True)
    else:
        parser = VisibleText()
        parser.feed(body)
        normalized = ' '.join(' '.join(parser.parts).split())
    return hashlib.sha256(normalized.encode()).hexdigest()

def changes(previous, current):
    return [key for key in current if key in previous and previous[key] != current[key]]

def api(path, data=None, method=None):
    token = os.environ['GH_TOKEN']
    req = urllib.request.Request('https://api.github.com' + path,
        data=None if data is None else json.dumps(data).encode(),
        headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'unifi-upstream-watch', 'Content-Type': 'application/json'},
        method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)

def main():
    repo = os.environ['GH_REPO']
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repo):
        raise ValueError('Invalid repository identifier')
    existing = None
    page = 1
    while True:
        issues = api(f'/repos/{repo}/issues?state=all&per_page=100&page={page}')
        for issue in issues:
            if issue.get('title') == TITLE and issue.get('user', {}).get('login') == 'github-actions[bot]' and 'pull_request' not in issue:
                existing = issue
                break
        if existing or len(issues) < 100: break
        page += 1
    previous = {}
    if existing:
        match = re.search(r'<!-- unifi-state:(.*?) -->', existing.get('body') or '', re.S)
        if match: previous = json.loads(match.group(1))
    current, failures = {}, []
    for label, url in SOURCES.items():
        try:
            req = urllib.request.Request(url, headers={'User-Agent': 'unifi-upstream-watch'})
            with urllib.request.urlopen(req, timeout=30) as response:
                content = response.read(3_000_001)
            if len(content) > 3_000_000: raise ValueError('Source exceeds size limit')
            current[label] = digest(content.decode('utf-8'), url.startswith('https://api.github.com/'))
        except Exception:
            failures.append(label)
            if label in previous: current[label] = previous[label]
    changed = changes(previous, current)
    if existing and not changed and not failures and previous == current:
        print('No upstream changes detected')
        return
    summary = ('Changed sources: ' + ', '.join(changed)) if changed else 'Baseline or newly available sources recorded.'
    if failures: summary += '\nFetch failed (not evidence of compatibility): ' + ', '.join(failures)
    body = ('## Compatibility watch\n\n' + summary + '\n\n' +
        '\n'.join(f'- [{label}]({url})' for label, url in SOURCES.items()) +
        '\n\nPage changes are signals, not proven breaking changes. Review the source and create a scoped fix issue with affected versions and tests. No automatic code changes or releases.\n\n' +
        '<!-- unifi-state:' + json.dumps(current, sort_keys=True) + ' -->')
    if existing:
        if changed or failures:
            api(f"/repos/{repo}/issues/{existing['number']}/comments", {'body': summary})
        api(f"/repos/{repo}/issues/{existing['number']}", {'body': body, 'state': 'open'}, 'PATCH')
    else:
        api(f'/repos/{repo}/issues', {'title': TITLE, 'body': body})
    if failures: raise SystemExit('Some upstream sources could not be checked')

if __name__ == '__main__':
    main()
