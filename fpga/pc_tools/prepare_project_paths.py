"""Relocate generated IP configuration paths after extracting the project elsewhere."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
def main():
    changed=[]
    for p in (ROOT/'ip').rglob('settings.json'):
        obj=json.loads(p.read_text(encoding='utf-8-sig'));args=obj.get('args',[])
        if '--base_path' not in args:continue
        i=args.index('--base_path')+1;target=str(ROOT/'ip')
        if args[i]!=target:
            args[i]=target;p.write_text(json.dumps(obj,indent=2),encoding='utf8');changed.append(p.relative_to(ROOT).as_posix())
    print('IP configuration paths prepared:',len(changed),'updated; root =',ROOT)
if __name__=='__main__':main()
