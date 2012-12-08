/*

  Spinbot speces people should know.
  if you need to make new data structer put it here 
  so people will know how to use it


  Our spim conventions

  
  $s5 - $s7 and $t7 - $t10 are not to be used by
  or stored away in funtions. They are saved for use as defind here:

  $s5: 
 

	$t8 and $t10: used in sort_list, should be restored when interrupting
	$t9: constant value = 1
 $s7:  constant value = 15
$s6: curr scan location


  more to come use on code you need to run alot.


	MAKE SURE that new nodes added to the list have their next point to 0!
 */


struct token {
  int x; //0
  int y; //4
  int zone; //12
};

struct scanData{
  scanOutput * [10];
};
struct scanOutput{
  void * [15] linkedLists 
};
