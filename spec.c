/*

  Spinbot speces people should know.
  if you need to make new data structer put it here 
  so people will know how to use it


  Our spim conventions
  
  $s5 - $s7 and $t7 - $t10 are not to be used by
  or stored away in funtions. They are saved for use as defind here:

  $s5: the head of the token list
  $s6: the tail of the token list 

  more to come use on code you need to run alot.


	MAKE SURE that new nodes added to the list have their next point to 0!
 */
struct tokenlist{
  token * head;
  token * tail;
};

struct token {
  int x; //0
  int y; //4
  token * next; //12
  int zone; //16
};

struct scanData{
  scanOutput * [10];
};
struct scanOutput{
  void * [15] linkedLists 
};
