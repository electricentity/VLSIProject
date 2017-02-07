f = open('testvector.txt', 'r')
testvectors = [x.strip() for x in f.readlines()]

"""
data_out<23:0>
inputs<15:0> = {4b\'0000, data_out<23:12>}
outputs<15:0> = {4b\'0000, data_out<11:0>}
"""

inputs = [s[0:12] for s in testvectors]
in_len = len(inputs)
outputs = [s[12:24] for s in testvectors]
out_len = len(outputs)


print '/*'
print 'data_out<23:0>'
print 'inputs<15:0> = {4b\'0000, data_out<23:12>'
print 'outputs<15:0> = {4b\'0000, data_out<11:0>'
print '*/'

print '\n'

newline = 0;
print "const uint16_t PROGMEM input_vals[] = {"
all_inputs = ''
for a in inputs:
    all_inputs += hex(int(a,2)) + ', '
    newline += 1;
    if newline == 8:
        all_inputs += '\n'
        newline = 0
print all_inputs[:-2]
print "};"
    
print '\n'

newline = 0;
print "const uint16_t PROGMEM output_vals[] = {"
all_outputs = ''
for b in outputs:
    all_outputs += hex(int(b,2)) + ', '
    newline += 1;
    if newline == 8:
        all_outputs += '\n'
        newline = 0
print all_outputs[:-2]
print "};"
