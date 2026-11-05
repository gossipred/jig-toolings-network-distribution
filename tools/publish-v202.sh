#!/usr/bin/env bash
# Reviewed local artifacts only. No git push or production commands.
set -euo pipefail
exec /usr/bin/python3 -I - "$@" <<'PY'
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

PIN = "a323d6ed530883819529526aa3a162d1b8020aca315f3c600545fe30aba4b7c6"
REPO = 'gossipred/jig-toolings-network-distribution'
TAG = 'v2.0.2'
ROOT = Path(os.environ.get('JIG_RELEASE_DIR', str(Path.home()/'Developer/jig-network-release-20261105'))).resolve()
IDS = [652413495,652413483,650067495,650067496,596837219,596837227,594457180,594457194,593977942,593977943,592939004,592939002,592577395,592577389,592412839,592413944]
REQUIRED = {'jig-toolings-network-windows-2.0.2.zip','JigToolingsSetup-2.0.2.exe',
 'jig-toolings-network-macos-2.0.2.zip','Jig-v2.0.2-Windows-Installation-and-Upgrade-Guide.pdf',
 'Jig-Network-Administrator-Manual-v2.0.2.docx','Jig-Network-User-Manual-v2.0.2.docx',
 'latest.json','latest.json.sig','RELEASE-NOTES.md','THIRD-PARTY-NOTICES.txt','update-signing-public.pem'}
REQUIRED.update({name+'-'+platform+'.txt' for name in ['PORT-CHANGE-GUIDE','RESTORE-GUIDE','UPDATE-GUIDE'] for platform in ['Windows','macOS']})
REQUIRED.update({'INSTALL-GUIDE-'+platform+'-'+language+'.txt' for platform in ['Windows','macOS'] for language in ['en','zh-TW']})

def run(args, **kwargs):
    return subprocess.run(args, check=True, timeout=600, **kwargs)

def gh(*args):
    return run(['gh', *args], capture_output=True, text=True).stdout

def digest(p):
    with p.open('rb') as f:
        h = hashlib.sha256()
        for chunk in iter(lambda: f.read(1024*1024), b''):
            h.update(chunk)
        return h.hexdigest()

def signature(folder, trusted_key):
    sig = base64.b64decode((folder/'latest.json.sig').read_bytes(), validate=True)
    with tempfile.NamedTemporaryFile(prefix='jig-release-sig-') as temp:
        temp.write(sig); temp.flush()
        run(['/usr/bin/openssl','dgst','-sha256','-verify',str(trusted_key),'-signature',temp.name,str(folder/'latest.json')], capture_output=True)

def local():
    assert digest(ROOT/'checksums.txt') == PIN, 'checksums.txt differs from reviewed publisher seal'
    items = {}
    for line in (ROOT/'checksums.txt').read_text().splitlines():
        match = re.fullmatch(r'([a-f0-9]{64})  ([A-Za-z0-9_.-]+)', line)
        assert match, 'Invalid checksum line'
        sha, name = match.groups()
        assert name not in items and 'XAMPP' not in name.upper(), 'Duplicate or forbidden asset'
        assert (ROOT/name).is_file() and not (ROOT/name).is_symlink(), 'Missing or linked asset: '+name
        assert digest(ROOT/name) == sha, 'Hash mismatch: '+name
        items[name] = sha
    assert set(items) == REQUIRED, 'Unexpected or missing release assets'
    signature(ROOT, ROOT/'update-signing-public.pem')
    manifest = json.loads((ROOT/'latest.json').read_text())
    assert manifest['latestVersion'] == '2.0.2', 'Wrong manifest version'
    base = 'https://github.com/'+REPO+'/releases/download/'+TAG+'/'
    for platform in ['windows','macos']:
        p=manifest['platforms'][platform]; name='jig-toolings-network-'+platform+'-2.0.2.zip'
        assert p['packageUrl'] == base+name and p['sha256'] == items[name], 'Manifest package mismatch'
    win=manifest['platforms']['windows']; name='JigToolingsSetup-2.0.2.exe'
    assert win['installerUrl'] == base+name and win['installerSha256'] == items[name], 'Manifest installer mismatch'
    return items

def releases():
    # --slurp keeps paginated JSON well formed; auth/network failure must abort.
    pages=json.loads(gh('api','--paginate','--slurp','repos/'+REPO+'/releases?per_page=100'))
    if pages and isinstance(pages[0],list):
        return [release for page in pages for release in page]
    return pages

def find_release():
    matches=[r for r in releases() if r['tag_name']==TAG]
    assert len(matches)<=1, 'Duplicate release tag'
    return matches[0] if matches else None

def preflight():
    items=local()
    assert find_release() is None, TAG+' already exists; inspect the existing release/draft before retrying'
    target=os.environ.get('JIG_RELEASE_TARGET','')
    assert re.fullmatch('[a-f0-9]{40}',target), 'Set JIG_RELEASE_TARGET to the reviewed distribution commit already available on GitHub'
    gh('api','repos/'+REPO+'/commits/'+target)
    print('Preflight PASS: reviewed hashes, signature, remote target and absent release')
    return items,target

def verify(items, allow_draft=False):
    release=find_release()
    assert release, TAG+' is missing'
    assert allow_draft or not release['draft'], 'Release is still a draft'
    names=[a['name'] for a in release['assets']]
    expected=set(items)|{'checksums.txt'}
    print('Remote assets: '+', '.join(sorted(names)))
    assert len(names)==len(expected) and set(names)==expected, 'Remote asset list differs; XAMPP/extra/missing/duplicate assets forbidden'
    with tempfile.TemporaryDirectory(prefix='jig-release-download-') as work:
        dest=Path(work)
        gh('release','download',TAG,'--repo',REPO,'--dir',str(dest))
        assert {p.name for p in dest.iterdir()}==expected, 'Downloaded asset list differs'
        for name,sha in dict(items, **{'checksums.txt':PIN}).items():
            assert digest(dest/name)==sha, 'Downloaded hash mismatch: '+name
        signature(dest,ROOT/'update-signing-public.pem')
    print('Verify PASS: downloaded SHA-256 and trusted latest.json signature')

def main():
    assert len(sys.argv)==2 and sys.argv[1] in ['preflight','publish','delete-xampp','verify'], 'Usage: publish-v202.sh preflight|publish|delete-xampp|verify'
    mode=sys.argv[1]
    if mode=='preflight':
        preflight()
    elif mode=='publish':
        items,target=preflight()
        gh('release','create',TAG,'--repo',REPO,'--target',target,'--draft','--title','Jig Toolings Network v2.0.2','--notes-file',str(ROOT/'RELEASE-NOTES.md'))
        try:
            gh('release','upload',TAG,*[str(ROOT/n) for n in sorted(set(items)|{'checksums.txt'})],'--repo',REPO)
            verify(items,allow_draft=True)
            gh('release','edit',TAG,'--repo',REPO,'--draft=false','--latest')
            verify(items)
        except BaseException:
            print('STOP: inspect GitHub v2.0.2 state. A draft is retained if failure occurred before publication; no automatic delete or push.',file=sys.stderr)
            raise
    elif mode=='verify':
        verify(local())
    else:
        verify(local())
        assets={a['id']:a for r in releases() for a in r['assets']}
        # Validate all remaining IDs before the first irreversible deletion.
        for i in IDS:
            if i in assets:
                assert assets[i]['name'] == ('XAMPP-installer.exe' if IDS.index(i)%2==0 else 'XAMPP-installer.dmg'), 'Refusing mismatched asset ID '+str(i)
        for i in IDS:
            if i not in assets:
                print('Already absent: '+str(i)); continue
            gh('api','repos/'+REPO+'/releases/assets/'+str(i),'--method','DELETE')
            print('Deleted '+str(i)+' '+assets[i]['name'],flush=True)
        remaining={a['id'] for r in releases() for a in r['assets']}
        assert not remaining.intersection(IDS), 'Some requested XAMPP assets remain'
        print('Delete verification PASS: all 16 historical IDs absent')

try:
    main()
except (AssertionError, OSError, ValueError, subprocess.SubprocessError) as error:
    print('STOP: '+str(error),file=sys.stderr)
    if isinstance(error,subprocess.CalledProcessError):
        print((error.stderr or b'').decode() if isinstance(error.stderr,bytes) else error.stderr or '',file=sys.stderr)
    sys.exit(1)
PY
