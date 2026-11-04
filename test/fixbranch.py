# Rewrites a too-long branch (from Merlin's "Bad Jump" error) as the
# opposite branch around a JMP. Usage: fixbranch.py file line
import sys, re
inv = {'beq':'bne','bne':'beq','bcc':'bcs','bcs':'bcc','bmi':'bpl','bpl':'bmi','bvc':'bvs','bvs':'bvc'}
path, n = sys.argv[1], int(sys.argv[2])
lines = open(path).read().split('\n')
l = lines[n-1]
m = re.match(r'^(\S*)(\s+)(b\w\w)(\s+)(\S+)(.*)$', l)
op, target = m.group(3), m.group(5)
lab = m.group(1)
k = 0
while any(x.startswith(f':jx{n}_{k} ') or x == f':jx{n}_{k}' for x in lines): k += 1
skip = f':jx{n}_{k}'
if op == 'bra':
    new = [f'{lab:<12}jmp   {target}']
else:
    new = [f'{lab:<12}{inv[op]}   {skip}', f'{"":<12}jmp   {target}', skip]
lines[n-1:n] = new
open(path, 'w').write('\n'.join(lines))
