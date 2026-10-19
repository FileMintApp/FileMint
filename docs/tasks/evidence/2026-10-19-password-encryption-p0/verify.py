from pathlib import Path
import json
import sys

base=Path(sys.argv[1])
main=[json.loads(x) for x in (base/'observations.jsonl').read_text().splitlines()]
extra=[json.loads(x) for x in (base/'followup.jsonl').read_text().splitlines()]
def one(rows,case,**match):
    values=[r for r in rows if r['case']==case and all(r.get(k)==v for k,v in match.items())]
    assert len(values)==1,(case,match,len(values))
    return values[0]
checks=[]
def check(name,condition):
    assert condition,name
    checks.append({'check':name,'passed':True})
check('raw bytes roundtrip',one(main,'raw_roundtrip')['equal'])
check('randomized ciphertext',one(main,'randomized_encryption')['differentCiphertext'])
for n in [19,20,256,257]:
    r=one(extra,'password_boundary_full_crypto',bytes=n)
    check('password boundary '+str(n),r['equal']==(n in [20,256]) and (r['encrypt']['returncode']==0)==(n in [20,256]))
for label in ['cjk8','cjk11','emoji8','space32','nul32','nfc','nfd']:
    check('UTF8 roundtrip '+label,one(main,'password_encoding',label=label)['roundtripEqual'])
for label in ['nfc','nfd']:
    check('Unicode alternate representation rejected '+label,not one(main,'unicode_cross_form',label=label)['result']['ok'])
folder=one(main,'folder_roundtrip')
check('directory contents modes mtime xattrs resource fork',folder['manifestEqual'] and folder['entryCount']==7)
for case in ['api_to_apple_cli','apple_cli_to_api']:check(case,one(main,case)['manifestEqual'])
for variant in ['wrong_password','header_flip','middle_flip','tail_flip','truncate_tail','truncate_half']:
    check('invalid archive rejected '+variant,not one(main,'damaged_or_wrong_password',variant=variant)['result']['ok'])
check('late error can leave plaintext',one(main,'damaged_or_wrong_password',variant='tail_flip')['outputBytes']>0)
check('raw API accepts trailing bytes',one(main,'damaged_or_wrong_password',variant='append_garbage')['result']['ok'])
for name in ['append_garbage.aea','truncate_tail.aea']:
    r=one(extra,'strict_length_observation',variant=name)
    check('authenticated length detects '+name,r['attributesAuthenticated'] and not r['lengthMatches'])
check('configuration change alone does not rekey',not one(main,'config_change_only')['newPasswordCanDecryptOld'])
m=one(main,'migration_stream_reencrypt')
check('stream migration verified without changing old',m['manifestEqual'] and m['oldPasswordRejected'] and m['oldArchiveUnchanged'])
p=one(main,'migration_publication')
check('new live old offline',p['newLiveDecrypts'] and p['offlineOldStillDecrypts'] and p['offlineOldUnchanged'])
f=one(main,'migration_interrupted')
check('injected stop never published',not f['result']['ok'] and f['oldArchiveUnchanged'] and not f['published'])
t=one(extra,'migration_process_termination')
check('SIGTERM candidate cannot replace old',t['exit']==-15 and t['candidateBytes']>0 and t['candidateDecrypt']['returncode']!=0 and t['oldArchiveUnchanged'] and not t['published'])
check('old readable after SIGTERM',one(extra,'old_archive_after_termination')['equal'])
large=one(extra,'large_streaming_migration')
check('64 MiB migration',large['inputBytes']==67108864 and large['equal'] and large['oldArchiveUnchanged'])
c=one(extra,'migration_output_collision')
check('candidate collision preserves both sides',c['result']['returncode']!=0 and c['outputPreserved'] and c['sourcePreserved'])
check('mixed batch versions explicit',one(main,'partial_batch_password_versions')['items']=={'item1':{'old':False,'new':True},'item2':{'old':True,'new':False}})
check('original fixtures intact',one(main,'final_source_preservation')['manifestEqual'] and one(main,'final_source_preservation')['oldArchiveUnchanged'])
print(json.dumps({'passed':True,'assertionGroups':len(checks),'observations':len(main)+len(extra),'checks':checks},indent=2))
