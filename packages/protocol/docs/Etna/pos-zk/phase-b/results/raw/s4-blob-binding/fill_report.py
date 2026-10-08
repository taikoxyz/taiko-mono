import sys
p = sys.argv[1]
s = open(p).read()
repl = {
 '{{P_MIN}}': '1,668,134',
 '{{C_MIN}}': '2.186e-7',
 '{{P_MED}}': '6,991,223',
 '{{C_MED}}': '9.164e-7',
 '{{P_P90}}': '33,430,313',
 '{{C_P90}}': '4.382e-6',
 '{{P_MAX}}': '675,350,452',
 '{{C_MAX}}': '8.852e-5',
 '{{N_HDR}}': '2,020 (5.0 % of the 40,474)',
 '{{MAX_BLOCK_BLOBS}}': '21 (3 of 400 sampled blocks; the full histogram is in the raw file)',
 '{{P_MIN_RANGE}}': '1.67 million',
 '{{P_MAX_RANGE}}': '675 million',
}
for k, v in repl.items():
    n = s.count(k)
    s = s.replace(k, v)
    print(k, '->', v, f'({n} occurrence(s))')
# tighten the orders-of-magnitude sentence
s = s.replace('the measured fee is six to eight orders of magnitude above it.',
              'the measured fee is between ~6 and ~9 orders of magnitude above it.')
open(p, 'w').write(s)
print('done')
