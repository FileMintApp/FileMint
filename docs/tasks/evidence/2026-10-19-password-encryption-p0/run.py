from pathlib import Path
import subprocess, json, tempfile, os, hashlib, random, shutil, time, unicodedata

root=Path(tempfile.mkdtemp(prefix='filemint-aea-p0-',dir='/private/tmp'))
os.chmod(root,0o700)
Path('/private/tmp/filemint-aea-p0-latest.json').write_text(json.dumps({'root':str(root)}))
binary='/private/tmp/filemint-aea-p0'
observations=[]
old='P0-only-old-password-never-use-for-real-data-2026'
new='P0-only-new-password-never-use-for-real-data-2026'
wrong='P0-only-bad-password-never-use-for-real-data-2026'
def record(case,**values):
    row={'case':case,**values};observations.append(row)
    with (root/'observations.jsonl').open('a') as f:f.write(json.dumps(row,ensure_ascii=False,sort_keys=True)+'\n')
    print(json.dumps(row,ensure_ascii=False),flush=True)
def invoke(label,action,password=old,**kwargs):
    req={'action':action,'password':password,**{k:str(v) if isinstance(v,Path) else v for k,v in kwargs.items()}}
    p=subprocess.run([binary],input=json.dumps(req).encode(),capture_output=True,timeout=90)
    (root/(label+'.stderr.txt')).write_bytes(p.stderr)
    try:r=json.loads(p.stdout)
    except Exception:r={'ok':False,'stage':'process','returncode':p.returncode,'stdout':p.stdout.decode(errors='replace')[:500]}
    r['returncode']=p.returncode
    return r
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def writeattr(p,key,value):
    subprocess.run(['/usr/bin/xattr','-wx',key,value.hex(),str(p)],check=True,capture_output=True)
def readattrs(p):
    names=subprocess.check_output(['/usr/bin/xattr',str(p)],text=True).splitlines()
    return {name:hashlib.sha256(bytes.fromhex(subprocess.check_output(['/usr/bin/xattr','-px',name,str(p)],text=True))).hexdigest() for name in names}
def snapshot(p):
    result={}
    for q in sorted(p.rglob('*')):
        st=q.lstat(); attrs=readattrs(q)
        result[str(q.relative_to(p))]={'kind':'link' if q.is_symlink() else 'directory' if q.is_dir() else 'file','mode':st.st_mode&0o777,'mtime_ns':st.st_mtime_ns,'size':st.st_size if q.is_file() else None,'digest':digest(q) if q.is_file() else None,'xattrs':attrs}
    return result
def differences(a,b):return {k:{'expected':a.get(k),'actual':b.get(k)} for k in a.keys()|b.keys() if a.get(k)!=b.get(k)}
def must(ok,label):
    if not ok:raise AssertionError(label)

print('P0_ROOT='+str(root),flush=True)
payload=root/'payload.bin';payload.write_bytes(random.Random(125).randbytes(3*1024*1024+17))
for length in [0,1,7,8,15,16,20,31,32,33,63,64,127,128,255,256,1023,1024,4096,65536]:
    r=invoke('length-'+str(length),'validatePassword',password='p'*length)
    record('password_length',utf8Bytes=length,result=r)
for label,password in [('cjk8','密'*8),('cjk11','密'*11),('emoji8','🔐'*8),('space32',' '*32),('nul32','p'*16+'\0'+'q'*15),('nfc','x'*31+'é'),('nfd','x'*31+'e\u0301')]:
    target=root/(label+'.aea')
    enc=invoke(label+'-enc','encrypt',password=password,input=payload,output=target)
    dec=invoke(label+'-dec','decrypt',password=password,input=target,output=root/(label+'.out')) if enc['ok'] else None
    equal=(root/(label+'.out')).exists() and digest(root/(label+'.out'))==digest(payload)
    record('password_encoding',label=label,characters=len(password),utf8Bytes=len(password.encode()),encrypt=enc,decrypt=dec,roundtripEqual=equal)
for label,other in [('nfc','x'*31+'e\u0301'),('nfd','x'*31+'é')]:
    r=invoke(label+'-other','decrypt',password=other,input=root/(label+'.aea'),output=root/(label+'-other.out'))
    record('unicode_cross_form',label=label,result=r)
raw=root/'raw-old.aea';enc=invoke('raw-old','encrypt',input=payload,output=raw);must(enc['ok'],'raw encrypt')
out=root/'raw-roundtrip.bin';dec=invoke('raw-roundtrip','decrypt',input=raw,output=out)
must(dec['ok'] and digest(out)==digest(payload),'raw roundtrip')
record('raw_roundtrip',encrypt=enc,decrypt=dec,equal=True,inputBytes=payload.stat().st_size,archiveBytes=raw.stat().st_size)
enc2=root/'raw-second.aea';must(invoke('raw-second','encrypt',input=payload,output=enc2)['ok'],'repeat encrypt')
record('randomized_encryption',differentCiphertext=digest(raw)!=digest(enc2))

folder=root/'source';(folder/'层级'/'empty').mkdir(parents=True)
(folder/'empty-root').mkdir()
(folder/'zero').write_bytes(b'')
(folder/'层级'/'name with spaces.txt').write_bytes('FileMint P0 Unicode 内容\n'.encode())
(folder/'binary.bin').write_bytes(payload.read_bytes())
meta=folder/'meta.txt';meta.write_bytes(b'metadata P0 fixture')
os.chmod(meta,0o640)
writeattr(meta,'com.filemint.p0.test',b'isolated xattr payload')
writeattr(meta,'com.apple.ResourceFork',b'isolated resource fork payload')
writeattr(folder/'empty-root','com.filemint.p0.folder',b'empty directory metadata')
for p in folder.rglob('*'):os.utime(p,ns=(1600000000123456789,1600000000123456789))
before=snapshot(folder);(root/'source-manifest.json').write_text(json.dumps(before,ensure_ascii=False,indent=2))
archive=root/'folder-old.aea';pack=invoke('folder-pack','pack',input=folder,output=archive)
must(pack['ok'],'pack')
restored=root/'folder-restored';extract=invoke('folder-extract','extract',input=archive,output=restored)
diff=differences(before,snapshot(restored)) if extract['ok'] else {}
record('folder_roundtrip',pack=pack,extract=extract,entryCount=len(before),manifestEqual=not diff,differences=diff)
must(extract['ok'],'extract')
record('source_preserved',manifestEqual=snapshot(folder)==before)
record('ciphertext_visibility',filenameFound=b'meta.txt' in archive.read_bytes(),contentMarkerFound=b'metadata P0 fixture' in archive.read_bytes())

# Native tool interoperability uses only synthetic passwords in private files, never argv.
pw=root/'old-test-password';pw.write_text(old);os.chmod(pw,0o600)
cliAAR=root/'cli-decoded.aar'
p=subprocess.run(['/usr/bin/aea','decrypt','-i',str(archive),'-o',str(cliAAR),'-password',str(pw)],capture_output=True,timeout=90)
(root/'cli-decrypt.stderr.txt').write_bytes(p.stderr)
cliOut=root/'cli-extract';cliOut.mkdir()
q=subprocess.run(['/usr/bin/aa','extract','-i',str(cliAAR),'-d',str(cliOut)],capture_output=True,timeout=90) if p.returncode==0 else None
record('api_to_apple_cli',aeaExit=p.returncode,aaExit=q.returncode if q else None,manifestEqual=snapshot(cliOut)==before)
if q:(root/'cli-extract.stderr.txt').write_bytes(q.stderr)
cliEncrypted=root/'cli-encrypted.aea'
p=subprocess.run(['/usr/bin/aea','encrypt','-profile','5','-i',str(cliAAR),'-o',str(cliEncrypted),'-password',str(pw)],capture_output=True,timeout=90)
(root/'cli-encrypt.stderr.txt').write_bytes(p.stderr)
r=invoke('cli-to-api','extract',input=cliEncrypted,output=root/'cli-api-out') if p.returncode==0 else None
record('apple_cli_to_api',aeaExit=p.returncode,extract=r,manifestEqual=snapshot(root/'cli-api-out')==before if r and r['ok'] else False)

# Adversarial variants remain isolated; observe partial output rather than claiming transactional extraction.
original=archive.read_bytes()
variants={'wrong_password':original,'header_flip':bytes([original[0]^1])+original[1:],
          'middle_flip':original[:len(original)//2]+bytes([original[len(original)//2]^1])+original[len(original)//2+1:],
          'tail_flip':original[:-1]+bytes([original[-1]^1]),'truncate_tail':original[:-32],
          'truncate_half':original[:len(original)//2],'append_garbage':original+b'P0-appended-data'}
for label,data in variants.items():
    src=root/(label+'.aea');src.write_bytes(data);dest=root/(label+'-out')
    r=invoke(label,'extract',password=wrong if label=='wrong_password' else old,input=src,output=dest)
    record('damaged_or_wrong_password',variant=label,result=r,outputEntries=len(list(dest.rglob('*'))) if dest.exists() else 0,outputBytes=sum(x.stat().st_size for x in dest.rglob('*') if x.is_file()) if dest.exists() else 0)

# Same old archive, new global configuration password: no change to actual ciphertext.
r=invoke('new-password-before-migration','extract',password=new,input=archive,output=root/'premigration-new-out')
record('config_change_only',newPasswordCanDecryptOld=r['ok'],result=r)
saved=digest(archive);candidate=root/'folder-new.candidate.aea'
r=invoke('migration','rekey',input=archive,output=candidate,newPassword=new)
verify=root/'migration-verified';v=invoke('migration-verify','extract',password=new,input=candidate,output=verify) if r['ok'] else None
equal=v and v['ok'] and snapshot(verify)==before
oldReject=invoke('old-password-new-archive','extract',input=candidate,output=root/'new-with-old-out') if r['ok'] else None
record('migration_stream_reencrypt',result=r,newPasswordVerification=v,manifestEqual=bool(equal),oldPasswordRejected=oldReject is not None and not oldReject['ok'],oldArchiveUnchanged=digest(archive)==saved)
must(equal and not oldReject['ok'],'migration verification')
# Explicit publication is only over an owned copy, while offline copy remains old-password data.
live=root/'live.aea';shutil.copyfile(archive,live)
os.replace(candidate,live)
post=invoke('live-new','extract',password=new,input=live,output=root/'live-new-out')
offline=invoke('offline-old','extract',input=archive,output=root/'offline-old-out')
record('migration_publication',newLiveDecrypts=post['ok'],offlineOldStillDecrypts=offline['ok'],offlineOldUnchanged=digest(archive)==saved)

# Failure injection creates a candidate only, never replaces old source.
failed=root/'stopped.candidate.aea'
r=invoke('migration-stop','rekey',input=archive,output=failed,newPassword=new,stopAfterBytes=1048576)
check=invoke('stopped-check','extract',password=new,input=failed,output=root/'stopped-out') if failed.exists() else None
record('migration_interrupted',result=r,candidateExists=failed.exists(),candidateDecryptResult=check,oldArchiveUnchanged=digest(archive)==saved,published=False)
# Explicit two-entry batch migration, stopping before entry 2 publication.
batch=root/'batch';batch.mkdir()
shutil.copyfile(live,batch/'item1.aea');shutil.copyfile(archive,batch/'item2.aea')
batchResults={}
for name in ['item1','item2']:
    batchResults[name]={}
    for version,password in [('old',old),('new',new)]:
        t=invoke('batch-'+name+'-'+version,'extract',password=password,input=batch/(name+'.aea'),output=root/(name+'-'+version+'-out'))
        batchResults[name][version]=t['ok']
record('partial_batch_password_versions',items=batchResults)
must(batchResults=={'item1':{'old':False,'new':True},'item2':{'old':True,'new':False}},'batch versions')
record('final_source_preservation',manifestEqual=snapshot(folder)==before,oldArchiveUnchanged=digest(archive)==saved)
(root/'summary.json').write_text(json.dumps({'root':str(root),'observations':len(observations),'sourceEntries':len(before)},indent=2))
print('P0_FINISHED='+str(root),flush=True)
