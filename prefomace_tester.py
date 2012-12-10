from subprocess import Popen;
from subprocess import PIPE;
import sys
try:
    from collections import Counter
except ImportError:
    try:
        from recipe5766111 import Counter
    except ImportError:
        print "Counter not found"
        sys.exit(1)


import time
import random
import signal
heatmapSupport =True
try:
    import heatmap
except ImportError:
    heatmapSupport = False

class Alarm(Exception):
    pass

def alarm_handler(signum, frame):
    raise Alarm

signal.signal(signal.SIGALRM, alarm_handler)
signal.alarm(20)

def graptokens(rand) :
    if not type(rand) == str :
        rand = "-randomseed "+str(rand(1355029990,1355039990))+" -randommap"
    try :
        inline= Popen("./QtSpimbot -file done.s "+rand+ 
                      " -maponly  -debug   -run  -exit_when_done", stdout=PIPE, shell=True).stdout
        string = "not"
        pointList =[]
        while(not (string == '')) :
 
            string = inline.readline()
            if string[:6] == "TOKEN:" :
                nums=string[7:].split(" ")
                pointList.append( (int(nums[0]),int(nums[1])))
                
        return pointList
    except Alarm:
        killerror= Popen("killall QtSpimbot", stdout=PIPE, shell=True).stdout
        
        print "error"
        return []
    



def tokenheatmap(test_num,seed) :
    hm  = heatmap.Heatmap()
    tokenList =[]
    for x in xrange(0, test_num) :
        signal.alarm(20) 
        tokenList+=graptokens(seed)
    hm.heatmap(tokenList, 50, 120,(2048, 2048), 'classic', ((0,0),(300,300))).save("token_heat_map.png")


def runGame( seed_list, rand) :
    if not type(rand) == str :
        rand = "-randomseed "+str(rand(1355029990,1355039990))+" -randommap"
    print rand
    try :
        inline= Popen("./QtSpimbot -file spimbot.s -run "+rand+ " -exit_when_done -maponly -quiet ", stdout=PIPE, shell=True).stdout
        string = "not"
        while(not (string == '')) :
            string = inline.readline()
            if string[:7] == "cycles:" :
                return  [string[7:-1]]
        return ["error, What? This should not be so?"]
    except Alarm:
        print "your bot is too slow"
        killerror= Popen("killall QtSpimbot", stdout=PIPE, shell=True).stdout
        print  killerror.read()
        time.sleep(1)
        seed_list.append(rand[12:-11])

        return ["fail"] 
   

def runTwoPlayers( seed_list, rand) :
    if not type(rand) == str :
        rand = "-randomseed "+str(rand(1355029990,1355039990))+" -randommap"
    print rand
    try :
        inline= Popen("./QtSpimbot -file spimbot.s -file2 spimbot2.s -run "+rand+ " -exit_when_done -maponly -quiet ", stdout=PIPE, shell=True).stdout
        string = "not"
        out_come =[]
        while(not (string == '')) :
            string = inline.readline()
            if string[:7] == "cycles:" :
                out_come.append(string[7:-1])
            if string[:7] == "winner:"  :
                out_come.append(string)
                return  out_come
        return ["error, What? This should not be so?"]
    except Alarm:
        print "your bot is too slow"
        killerror= Popen("killall QtSpimbot", stdout=PIPE, shell=True).stdout
        print  killerror.read()
        time.sleep(1)
        seed_list.append(rand[12:-11])

        return ["fail"] 


def runtests(run, test_num,seed_list,seed ="-randommap"):
  

    for x in xrange(0, test_num) :
        signal.alarm(15) 
        for y in run(seed_list,seed) :
            count[y] +=1
    print "histogram :"
    print count.most_common()

    min_time = None
    for x in count.elements() : 
        l=[min_time ,x]
        min_time= min(i for i in l if (i is not None) and (i[0:7] is not  "winner:"))
    print "minimum time: ", min_time

    max_time = None
    for x in count.elements() : 
        if not x[:7] == "winner:" :
            max_time= max(max_time, x)
    print "max time: ", max_time

    avg =0;
    
    for x in count.elements() :   
   
        if x is not 'fail' :
  
            if not x[0:7] ==  "winner:" :
                avg+=int(x)
    avg/=test_num
    print "avg runtime: ", avg


if __name__ == "__main__" :
    if (len(sys.argv) < 3) or str(sys.argv[0]) == "--help" :
        print """

SpimBot testing tool by Silverdev 


usage  spimTweek <scan type>  <number of times>  <seed type>  <seed> 
--help:  prints this

values
<scan type> : single, double, token
<number of times> : int
<seed type>  : defalt, random, static  <seed>, setOrder <seed> 


"""
        sys.exit(1)
    test_num =int(sys.argv[2])
    print str(sys.argv)
    setting ={"single":0,"double":1,"token":3}
    if setting[sys.argv[1]] is 3 :
        if heatmapSupport :
            tokenheatmap(test_num,"-randommap")
            print "done"
            sys.exit(0)
        else :
            print "\n \n Error: heatmap.py not found"
            sys.exit(1)
        
    gamerunner=lambda x,y,z: runtests((runGame,runTwoPlayers) \
                                          [setting[str(sys.argv[1])]],x,y,z)
    
    count = Counter()
    r=random

    if str(sys.argv[3]) == "defalt" :
        r.seed("good luck")
    if str(sys.argv[3])  == "setOrder" :
        r.seed(sys.argv[4])

    failed_seed_list = []
    if str(sys.argv[3]) == "random" :
        gamerunner(test_num,failed_seed_list,"-randommap")
    if  str(sys.argv[3]) == "static" :
        gamerunner(test_num,failed_seed_list,"-randomseed "+str(sys.argv[4]) \
                       +" -randommap") 
    else :
        gamerunner(test_num, failed_seed_list, r.randint)
    if not failed_seed_list ==[] :
        print "the following seeds failed", failed_seed_list

