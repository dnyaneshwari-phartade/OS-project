#include "types.h"
#include "stat.h"
#include "user.h"

int passed = 0;
int failed = 0;

void
check(char *name, int ok)
{
  if(ok){
    printf(1, "PASSED: %s\n", name);
    passed++;
  } else {
    printf(1, "FAILED: %s\n", name);
    failed++;
  }
}

int
main(void)
{
  int p1[2], p2[2];
  int child, gpid = 0;
  char c = 'x';

  // simple checks that need no child
  check("setpgid on self returns 0", setpgid(0, 0) == 0);
  check("jobstate of a running process is 1", jobstate(getpid()) == 1);
  check("jobstate of a missing pid is 0", jobstate(9999) == 0);
  check("setpgid on a missing pid is refused", setpgid(9999, 0) == -1);
  check("setpgid on a non-child (init) is refused", setpgid(1, 5) == -1);
  check("killpg on group 1 (the shell) is refused", killpg(1) == -1);
  check("contpg returns 0", contpg(getpid()) == 0);

  // group test: child becomes a leader, grandchild inherits its group
  pipe(p1);
  pipe(p2);
  child = fork();
  if(child == 0){
    int g;
    read(p1[0], &c, 1);               // wait until the parent made me a leader
    g = fork();
    if(g == 0){
      while(1)
        sleep(10);
    }
    write(p2[1], &g, sizeof(g));      // tell the parent the grandchild's pid
    while(1)
      sleep(10);
  }
  setpgid(child, child);
  write(p1[1], &c, 1);
  read(p2[0], &gpid, sizeof(gpid));

  check("child is running (state 1)", jobstate(child) == 1);
  check("grandchild is running (state 1)", jobstate(gpid) == 1);
  check("setpgid on own child returns 0", setpgid(child, child) == 0);
  check("killpg on a child group returns 0", killpg(child) == 0);
  wait();
  sleep(20);
  check("child is dead after killpg", jobstate(child) == 0);
  check("grandchild died too (it inherited the group)", jobstate(gpid) == 0);

  printf(1, "RESULT: %d passed, %d failed\n", passed, failed);
  exit();
}