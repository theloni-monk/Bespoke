import time
from manta import Manta
m = Manta('lab08.yaml') # create manta python instance using yaml
#WRITEME: in-situ verification interface
val3 = 150
val4 = 12
m.lab8_io_core.val3_out.set(val3) # set the value val3_out to be val3
m.lab8_io_core.val4_out.set(val4) # set the value val4_out to be val4
time.sleep(0.01) # wait a little amount...though honestly this is isn't needed since Python is slow.
a = m.lab8_io_core.val1_in.get() # read in the output from our divider
b = m.lab8_io_core.val2_in.get() # read in the output from our divider
print(f"Values in were {val3} and {val4} with results {val4}//{val3}={val4//val3} and {val4}%{val3}={val4%val3}.")
print(f"Actual results were: {a} and {b}!")