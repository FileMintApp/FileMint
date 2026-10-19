from pathlib import Path
import json,subprocess,hashlib,time,random,os,signal
root=Path(json.loads(Path('/private/tmp/filemint-aea-p0-latest.json').read_text())['root'])
binary='/private/tmp/filemint-aea-p0'
old='P0-only-old-password-never-use-for-real-data-2026'
new='P0-only-new-password-never-use-for-real-data-2026'
def emit(case,**data):
    r={'case':case,**data}
    with (root/'followup.jsonl').open('a') as f:f.write(json.dumps(r,sort_keys=True)+'\n')
    print(json.dumps(r),flush=True)
def run(label,action,password=old,**args):
    req={'action':action,'password':password,**{k:str(v) if isinstance(v,Path) else v for k,v in args.items()}}
    p=subprocess.run([binary],input=json.dumps(req).encode(),capture_output=True,timeout=90)
    (root/(label+'.stderr.txt')).write_bytes(p.stderr)
    return {'returncode':p.returncode,'output':[json.loads(x) for x in p.stdout.splitlines()]}
def ok(r):return r['returncode']==0 and r['output'][-1]['ok']
def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as f:
        while b:=f.read(1048576):h.update(b)
    return h.hexdigest()
for n in [19,20,256,257]:
    arc=root/('full-boundary-'+str(n)+'.aea')
    enc=run('full-boundary-'+str(n),'encrypt',password='p'*n,input=root/'payload.bin',output=arc)
    out=root/('full-boundary-'+str(n)+'.bin')
    dec=run('full-boundary-decrypt-'+str(n),'decrypt',password='p'*n,input=arc,output=out) if ok(enc) else None
    emit('password_boundary_full_crypto',bytes=n,encrypt=enc,decrypt=dec,equal=dec is not None and ok(dec) and sha(out)==sha(root/'payload.bin'))
for label,password in [('nul_changed','p'*16+'\0'+'r'*15),('spaces_changed',' '*31+'x')]:
    source=root/('nul32.aea' if label=='nul_changed' else 'space32.aea')
    emit('password_byte_sensitivity',label=label,result=run(label,'decrypt',password=password,input=source,output=root/(label+'.out')))

# Large raw migration interruption: terminate only the subprocess created here, after candidate bytes appear.
large=root/'large-raw.bin'
block=random.Random(632).randbytes(1048576)
with large.open('xb') as f:
    for _ in range(64):f.write(block)
largeOld=root/'large-old.aea'
e=run('large-encrypt','encrypt',input=large,output=largeOld);assert ok(e)
before=sha(largeOld);candidate=root/'terminated.candidate.aea'
req={'action':'rekey','password':old,'newPassword':new,'input':str(largeOld),'output':str(candidate)}
p=subprocess.Popen([binary],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
p.stdin.write(json.dumps(req).encode());p.stdin.close();p.stdin=None
deadline=time.monotonic()+30
seen=0
while p.poll() is None and time.monotonic()<deadline:
    seen=candidate.stat().st_size if candidate.exists() else 0
    if seen>65536:
        p.terminate();break
    time.sleep(.001)
stdout,stderr=p.communicate(timeout=30)
(root/'terminated.stdout.txt').write_bytes(stdout);(root/'terminated.stderr.txt').write_bytes(stderr)
dec=run('terminated-check','decrypt',password=new,input=candidate,output=root/'terminated.bin') if candidate.exists() else None
emit('migration_process_termination',exit=p.returncode,candidateBytesBeforeSignal=seen,candidateBytes=candidate.stat().st_size if candidate.exists() else 0,candidateDecrypt=dec,oldArchiveUnchanged=sha(largeOld)==before,published=False)
v=run('old-after-termination','decrypt',input=largeOld,output=root/'old-after-termination.bin')
emit('old_archive_after_termination',result=v,equal=ok(v) and sha(large)==sha(root/'old-after-termination.bin'))

# Successful 64 MiB streaming rekey, then independent decryption and digest comparison.
largeNew=root/'large-new.aea'
m=run('large-migration','rekey',input=largeOld,output=largeNew,newPassword=new);assert ok(m)
v=run('large-new-verify','decrypt',password=new,input=largeNew,output=root/'large-new-verified.bin')
emit('large_streaming_migration',inputBytes=large.stat().st_size,migration=m,verification=v,equal=ok(v) and sha(large)==sha(root/'large-new-verified.bin'),oldArchiveUnchanged=sha(largeOld)==before)

# Refuse output collisions and preserve both preexisting output and source.
collision=root/'collision.candidate';collision.write_bytes(b'owned existing sentinel')
r=run('output-collision','rekey',input=largeOld,output=collision,newPassword=new)
emit('migration_output_collision',result=r,outputPreserved=collision.read_bytes()==b'owned existing sentinel',sourcePreserved=sha(largeOld)==before)

# Container-length checking on the same descriptor is required, in addition to stream authentication.
for name in ['raw-old.aea','folder-old.aea','large-new.aea','append_garbage.aea','truncate_tail.aea']:
    r=run('length-'+name,'inspect',password=new if name=='large-new.aea' else old,input=root/name)
    attrs=next((x for x in r['output'] if x.get('case')=='attributes'),{})
    emit('strict_length_observation',variant=name,actual=(root/name).stat().st_size,authenticatedContainerSize=attrs.get('containerAfter'),attributesAuthenticated=attrs.get('authenticated'),lengthMatches=(root/name).stat().st_size==attrs.get('containerAfter'))
print('P0_FOLLOWUP_FINISHED',flush=True)
