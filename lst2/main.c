/*
    Little Smalltalk, version 2
    Written by Tim Budd, Oregon State University, July 1987

    driver (front-end) for bytecode interpreter.
*/
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "env.h"
#include "interp.h"
#include "memory.h"
#include "names.h"

extern int processStackTop;
extern object processStack[];
extern char tempfilename[];

void initMemoryManager();
void sysError(char *s1, char *s2);
void imageRead(FILE *fp);
void initCommonSymbols();
int objcount();
void prpush(object newobj);
void sendMessage(object message, object startingClass, int argumentPosition);
object getClass(object obj);
void flushstack();
void imageWrite(FILE *fp);

int main(int argc, char **argv)
{
  FILE *fp;
  initMemoryManager();

  if ((argc == 1) || ((argc > 1) && streq(argv[1], "-")))
  {
    fp = fopen(INITIALIMAGE, "r");
    if (fp == NULL)
      sysError("cannot read image file", INITIALIMAGE);
  }
  else
  {
    fp = fopen(argv[1], "r");
    if (fp == NULL)
      sysError("cannot read image file", argv[1]);
  }
  imageRead(fp);
  ignore fclose(fp);

  initCommonSymbols();

  ignore strcpy(tempfilename, TEMPFILENAME);
  ignore mkstemp(tempfilename);

  fprintf(stderr, "initially %d objects\n", objcount());

  /* now we are ready to start */
  prpush(smallobj);
  sendMessage(newSymbol("init"), getClass(smallobj), 0);
  flushstack();

  fprintf(stderr, "finally %d objects\n", objcount());

  if (argc > 2)
  {
    fp = fopen(argv[2], "w");
    if (fp == NULL)
      sysError("cannot write image file", argv[2]);
    fprintf(stderr, "creating image file %s\n", argv[2]);
    imageWrite(fp);
    ignore fclose(fp);
  }
  return 0;
}
