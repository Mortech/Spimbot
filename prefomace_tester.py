from subprocess import Popen;
from subprocess import PIPE;
from collections import Counter
import time
import random
import signal

class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)
signal.alarm(20)



def runGame( seed_list, rand) :
    if rand is not None:
        rand = "-randomseed "+str(rand(1355029990,1355039990))+" -randommap"
    print rand
    try :
        inline= Popen("./QtSpimbot -file spimbot.s -run "+rand+ " -exit_when_done -maponly -quiet ", stdout=PIPE, shell=True).stdout
        string = "not"
        while(not (string == '')) :
            string = inline.readline()
            if string[:7] == "cycles:" :
                return  string[7:-1]
        return "error, What? This should not be so?"
    except Alarm:
        print "your bot is too slow"
        killerror= Popen("killall QtSpimbot", stdout=PIPE, shell=True).stdout
        print  killerror.read()
        time.sleep(1)
         
        return "fail" 
   


def runtests(test_num,seed_list,seed =None):
  

    for x in xrange(0, test_num) :
        signal.alarm(15) 
        count[runGame(seed_list,seed)] +=1
    print "histogram :"
    print count.most_common()

    min_time = None
    for x in count.elements() : 
        l=[min_time ,x]
        min_time= min(i for i in l if i is not None)
    print "minimum time: ", min_time

    max_time = None
    for x in count.elements() :   
        max_time= max(max_time, x)
    print "max time: ", max_time

    avg =0;
    for x in count.elements() :   
        avg+=int(x)
    avg/=test_num
    print "avg runtime: ", max_time


test_num =2      
count = Counter()
r=random
r.seed("good luck")
failed_seed_list = {}
#runtests(test_num,failed_seed_list)
runtests(test_num, failed_seed_list, r.randint)
