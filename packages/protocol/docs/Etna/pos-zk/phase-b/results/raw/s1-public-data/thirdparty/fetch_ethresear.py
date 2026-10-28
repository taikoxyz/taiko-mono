import re, html, sys, urllib.request

def get(url, ua='Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124 Safari/537.36'):
    req = urllib.request.Request(url, headers={'user-agent': ua})
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read().decode('utf-8', 'ignore')

t = get('https://ethresear.ch/t/measuring-per-opcode-proving-time/23955')
open('thirdparty/ethresear_ch_opcode_proving.html', 'w').write(t)
x = re.sub(r'<script.*?</script>', ' ', t, flags=re.S)
x = re.sub(r'<style.*?</style>', ' ', x, flags=re.S)
x = re.sub(r'<[^>]+>', ' ', x)
x = html.unescape(x)
x = re.sub(r'\s+', ' ', x)
open('thirdparty/ethresear_ch_opcode_proving.txt', 'w').write(x)
print('chars', len(x))
for kw in ['GPU', '5090', '4090', 'multi-GPU', 'seconds', 'ms', 'marginal', 'conclusion', 'Conclusion']:
    i = x.find(kw)
    if i >= 0:
        print('---', kw, '---')
        print(x[max(0, i - 300):i + 900])
        print()
