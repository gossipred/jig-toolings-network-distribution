"""Exercise the actual release script with a stateful local gh stand-in."""
import base64
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'tools/publish-v202.sh'


class PublishTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        assert SCRIPT.exists(), 'release publisher is missing'

    def setUp(self):
        self.work = Path(tempfile.mkdtemp(prefix='jig-publish-test-'))
        self.addCleanup(lambda: subprocess.run(['trash', str(self.work)], check=True))
        self.assets = ['jig-toolings-network-windows-2.0.2.zip', 'JigToolingsSetup-2.0.2.exe',
                       'jig-toolings-network-macos-2.0.2.zip', 'Jig-v2.0.2-Windows-Installation-and-Upgrade-Guide.pdf',
                       'Jig-Network-Administrator-Manual-v2.0.2.docx', 'Jig-Network-User-Manual-v2.0.2.docx']
        self.assets += [name+'-'+platform+'.txt' for name in ['PORT-CHANGE-GUIDE','RESTORE-GUIDE','UPDATE-GUIDE'] for platform in ['Windows','macOS']]
        self.assets += ['INSTALL-GUIDE-'+platform+'-'+language+'.txt' for platform in ['Windows','macOS'] for language in ['en','zh-TW']]
        for name in self.assets:
            (self.work/name).write_text('test artifact '+name)
        data = {'latestVersion': '2.0.2', 'platforms': {}}
        for osname in ['windows', 'macos']:
            name = f'jig-toolings-network-{osname}-2.0.2.zip'
            data['platforms'][osname] = {'packageUrl': 'https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/'+name,
                                       'sha256': hashlib.sha256((self.work/name).read_bytes()).hexdigest()}
        data['platforms']['windows'].update(installerUrl='https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v2.0.2/'+self.assets[1],
                                            installerSha256=hashlib.sha256((self.work/self.assets[1]).read_bytes()).hexdigest())
        (self.work/'latest.json').write_text(json.dumps(data))
        (self.work/'RELEASE-NOTES.md').write_text('Release v2.0.2')
        (self.work/'THIRD-PARTY-NOTICES.txt').write_text('test notices')
        subprocess.run(['openssl', 'genrsa', '-out', str(self.work/'key'), '2048'], check=True, capture_output=True)
        subprocess.run(['openssl', 'rsa', '-in', str(self.work/'key'), '-pubout', '-out', str(self.work/'update-signing-public.pem')], check=True, capture_output=True)
        sig = subprocess.check_output(['openssl', 'dgst', '-sha256', '-sign', str(self.work/'key'), str(self.work/'latest.json')])
        (self.work/'latest.json.sig').write_bytes(base64.b64encode(sig))
        names = self.assets + ['latest.json', 'latest.json.sig', 'RELEASE-NOTES.md', 'THIRD-PARTY-NOTICES.txt', 'update-signing-public.pem']
        checks = ''.join(hashlib.sha256((self.work/n).read_bytes()).hexdigest()+'  '+n+'\n' for n in names)
        (self.work/'checksums.txt').write_text(checks)
        pin = hashlib.sha256(checks.encode()).hexdigest()
        script = SCRIPT.read_text()
        import re
        script = re.sub(r'PIN = "[^"]+"', 'PIN = "'+pin+'"', script)
        (self.work/'publish-v202.sh').write_text(script)
        self.state = {'release': None, 'uploaded': [], 'deleted': [], 'legacy': []}
        self.save()
        fake = self.work/'bin'; fake.mkdir()
        (fake/'gh').write_text('''#!/usr/bin/env python3
import json, os, pathlib, shutil, sys
p=pathlib.Path(os.environ['JIG_RELEASE_DIR']); f=p/'state.json'; s=json.loads(f.read_text()); a=sys.argv[1:]
def save(): f.write_text(json.dumps(s))
if os.environ.get('FAIL_GH'): sys.exit(9)
if a[:2]==['api','--paginate']:
 print(json.dumps(([s['release']] if s['release'] else [])+s['legacy'])); sys.exit()
if a[0]=='api' and '/commits/' in a[1]: print('{}'); sys.exit()
if a[:2]==['release','create']:
 s['release']={'id':202,'tag_name':'v2.0.2','draft':True,'assets':[]}; save(); sys.exit()
if a[:2]==['release','upload']:
 if os.environ.get('FAIL_UPLOAD'): sys.exit(8)
 for n in a[3:a.index('--repo')]:
  name=pathlib.Path(n).name; s['uploaded'].append(name); s['release']['assets'].append({'name':name,'id':len(s['uploaded'])})
 save(); sys.exit()
if a[:2]==['release','download']:
 dest=pathlib.Path(a[a.index('--dir')+1]); dest.mkdir(exist_ok=True)
 for n in s['uploaded']: shutil.copyfile(p/n,dest/n)
 if os.environ.get('BAD_DOWNLOAD'): (dest/s['uploaded'][0]).write_text('corrupt')
 sys.exit()
if a[:2]==['release','edit']:
 s['release']['draft']=False; save(); sys.exit()
if a[0]=='api' and '--method' in a:
 ident=int(a[1].split('/')[-1]); s['deleted'].append(ident)
 for r in s['legacy']: r['assets']=[x for x in r['assets'] if x['id']!=ident]
 save(); sys.exit()
sys.exit('unsupported gh invocation '+repr(a))
''')
        (fake/'gh').chmod(0o755)
        self.env = dict(os.environ, PATH=str(fake)+':'+os.environ['PATH'], JIG_RELEASE_DIR=str(self.work), JIG_RELEASE_TARGET='a'*40)

    def save(self):
        (self.work/'state.json').write_text(json.dumps(self.state))

    def run_mode(self, mode, **env):
        result = subprocess.run(['bash', str(self.work/'publish-v202.sh'), mode], env=dict(self.env, **env), capture_output=True, text=True)
        self.state = json.loads((self.work/'state.json').read_text())
        return result

    def test_preflight(self):
        self.assertEqual(self.run_mode('preflight').returncode, 0)

    def test_tamper_prevents_mutation(self):
        (self.work/self.assets[0]).write_text('tampered')
        self.assertNotEqual(self.run_mode('publish').returncode, 0)
        self.assertIsNone(self.state['release'])

    def test_python_optimization_cannot_disable_release_checks(self):
        (self.work/self.assets[0]).write_text('tampered')
        self.assertNotEqual(self.run_mode('publish', PYTHONOPTIMIZE='1').returncode, 0)
        self.assertIsNone(self.state['release'])

    def test_network_failure_is_not_release_absence(self):
        self.assertNotEqual(self.run_mode('publish', FAIL_GH='1').returncode, 0)
        self.assertIsNone(self.state['release'])

    def test_invalid_signature_is_refused_even_with_matching_hashes(self):
        (self.work/'latest.json.sig').write_bytes(base64.b64encode(b'bad signature'))
        checks=[]
        for line in (self.work/'checksums.txt').read_text().splitlines():
            name=line.split('  ')[1]
            checks.append(hashlib.sha256((self.work/name).read_bytes()).hexdigest()+'  '+name+'\n')
        raw=''.join(checks)
        (self.work/'checksums.txt').write_text(raw)
        import re
        p=self.work/'publish-v202.sh'
        p.write_text(re.sub(r'PIN = "[^"]+"','PIN = "'+hashlib.sha256(raw.encode()).hexdigest()+'"',p.read_text()))
        self.assertNotEqual(self.run_mode('preflight').returncode,0)
        self.assertIsNone(self.state['release'])

    def test_existing_release_refused(self):
        self.state['release']={'tag_name':'v2.0.2','draft':False,'assets':[]}; self.save()
        self.assertNotEqual(self.run_mode('preflight').returncode, 0)

    def test_publish_uploads_exact_allowlist_and_verifies(self):
        result=self.run_mode('publish')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.state['release']['draft'])
        self.assertEqual(set(self.state['uploaded']),set(self.assets+['latest.json','latest.json.sig','RELEASE-NOTES.md','THIRD-PARTY-NOTICES.txt','update-signing-public.pem','checksums.txt']))
        self.assertEqual(self.run_mode('verify').returncode, 0)

    def test_upload_failure_leaves_only_private_draft(self):
        self.assertNotEqual(self.run_mode('publish',FAIL_UPLOAD='1').returncode,0)
        self.assertTrue(self.state['release']['draft'])

    def test_download_tamper_does_not_publish(self):
        self.assertNotEqual(self.run_mode('publish',BAD_DOWNLOAD='1').returncode,0)
        self.assertTrue(self.state['release']['draft'])

    def test_all_delete_names_are_validated_before_first_deletion(self):
        self.assertEqual(self.run_mode('publish').returncode,0)
        ids=[652413495,652413483,650067495,650067496,596837219,596837227,594457180,594457194,593977942,593977943,592939004,592939002,592577395,592577389,592412839,592413944]
        self.state['legacy']=[{'tag_name':'old','assets':[{'id':i,'name':'XAMPP-installer.exe' if n%2==0 else 'XAMPP-installer.dmg'} for n,i in enumerate(ids)]}]
        self.state['legacy'][0]['assets'][-1]['name']='JigToolingsSetup.exe'; self.save()
        self.assertNotEqual(self.run_mode('delete-xampp').returncode,0)
        self.assertEqual(self.state['deleted'],[])

    def test_delete_exact_ids_and_idempotent_repeat(self):
        self.assertEqual(self.run_mode('publish').returncode,0)
        ids=[652413495,652413483,650067495,650067496,596837219,596837227,594457180,594457194,593977942,593977943,592939004,592939002,592577395,592577389,592412839,592413944]
        self.state['legacy']=[{'tag_name':'old','assets':[{'id':i,'name':'XAMPP-installer.exe' if n%2==0 else 'XAMPP-installer.dmg'} for n,i in enumerate(ids)]}]; self.save()
        result=self.run_mode('delete-xampp'); self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(self.state['deleted'],ids)
        self.assertEqual(self.run_mode('delete-xampp').returncode,0)
        self.assertEqual(self.state['deleted'],ids)


if __name__ == '__main__':
    unittest.main(verbosity=2)
