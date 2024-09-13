from command import Command, HwCertCommandException
import re

bw_output = Command("cat ./iperf3_output.txt").getStringList(regex=".*sender")
pattern = re.compile(r".*?(?P<speed>[\d\.]+)\s+Mbits/sec")
speed = 0.0

for output in bw_output:
	sp = pattern.match(output).group("speed")
	print("Bandwidth Output: '%s'\n Speed: %s Mb/sec" % (output, sp))
	speed += float(sp)

result = "\033[91m\033[1m(FAIL)" if int(speed) < 960 else "\033[96m\033[1m(PASS)"

print(f"\n🚀 Speed = {speed} Mb/s {result}\n\n")
