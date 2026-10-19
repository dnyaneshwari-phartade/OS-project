#include "types.h"
#include "stat.h"
#include "user.h"

int
main(void)
{
  int pid;

  printf(1, "setpgid(0,0)   = %d (want 0)\n", setpgid(0, 0));
  printf(1, "jobstate(me)   = %d (want 1)\n", jobstate(getpid()));
  printf(1, "jobstate(9999) = %d (want 0)\n", jobstate(9999));
  printf(1, "setpgid(9999,0)= %d (want -1)\n", setpgid(9999, 0));
  printf(1, "killpg(1)      = %d (want -1)\n", killpg(1));
  printf(1, "contpg(1)      = %d (want 0)\n", contpg(1));
  printf(1, "setfg(1)       = %d (want 0)\n", setfg(1));

  pid = fork();
  if(pid == 0){
    while(1)
      sleep(10);
  }
  setpgid(pid, pid);
  sleep(20);
  printf(1, "child state    = %d (want 1)\n", jobstate(pid));
  killpg(pid);
  wait();
  printf(1, "after killpg   = %d (want 0)\n", jobstate(pid));
  exit();
}
