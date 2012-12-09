from subprocess import Popen;
from subprocess import PIPE;
from collections import Counter
import time
import signal

class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)
signal.alarm(15)


def runGame() :
    try :
        inline= Popen("./QtSpimbot -file spimbot.s -run -exit_when_done -maponly -quiet ", stdout=PIPE, shell=True).stdout
        string = "not"
        while(not (string == '')) :
            string = inline.readline()
            if string[:7] == "cycles:" :
                return  string[7:-1]
        return "error this should not happen?"
    except Alarm:
        print "your bot is too slow"
        killerror= Popen("killall QtSpimbot", stdout=PIPE, shell=True).stdout
        print  killerror.read()
        time.sleep(1)
        signal.alarm(15)  
        return "fail" 
   
      
count = Counter()
for x in xrange(0, 10) :
   count[runGame()] +=1
print count
