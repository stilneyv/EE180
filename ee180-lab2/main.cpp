#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <locale.h>
#include <err.h>
#include "sobel_alg.h"

#define EPRINTF(...) fprintf(stderr, __VA_ARGS__)
struct opts opts;
char defaultVideo[] = {'b', 'a', 'x', 't', 'e', 'r', '.', 'a', 'v', 'i'};

void printHelp(int argc, char **argv)
{
  EPRINTF("EE 180 Lab2 driver\n");
  EPRINTF("Usage: %s OPTS\n", argv[0]);
  EPRINTF("OPTS can be a combination of the following:\n");
  EPRINTF("-n <num>  :  Number of frames after which program should quit. Must be a positive integer\n");
  EPRINTF("-m        :  Run the Multi-threaded version\n");
  EPRINTF("-f <file> :  Get input video from file. This is the default (defaults to 'baxter.avi' if unspecified)\n");
  EPRINTF("-w        :  Get input video from webcam (if connected to board). Must use either '-w' or '-f', not both\n");
}

void parseOpts(int argc, char **argv)
{
  int c;
  int inputSrc = 0;
  memset(&opts, 0, sizeof(struct opts));
  while ((c = getopt (argc, argv, "mwn:f:")) != -1) {
    switch (c) {
      case 'm':
        opts.multiThreaded = 1;
        break;
      case 'w':
        opts.webcam = 1;
        inputSrc++;
        break;
      case 'n':
        opts.numFrames = atoi(optarg);
        break;
      case 'f':
        opts.videoFile = optarg;
        inputSrc++;
        break;
      case '?':
        if (optopt == 'n' || optopt == 'f') {
          EPRINTF("Option %c requires an argument\n", optopt);
        }
        else if (isprint(optopt)) {
          EPRINTF("Unknown option %c\n", optopt);
        }
        else {
          EPRINTF("Unknown option character `\\x%x'\n", optopt);
        }
        exit(-1);
      default:
        printHelp(argc, argv);
        exit(-1);
    }
  }

  // Validate opts
  if (opts.numFrames <= 0) {
    EPRINTF("Invalid number of frames: %d (must be >0)\n", opts.numFrames);
    printHelp(argc, argv);
    exit(-1);
  }
  if (inputSrc == 0) {
    if (opts.videoFile == NULL) {
      opts.videoFile = defaultVideo;
    }
  } else if (inputSrc > 1) {
    EPRINTF("Both file and webcam options specified; please specify either -f or -w, not both\n");
    printHelp(argc, argv);
    exit(-1);
  }
  return;
}

int mainSingleThread()
{
  runSobelST();
  return 0;
}

// This mutex will be used to allow threads to contest for thread 0 status
pthread_barrier_t endSobel;
pthread_mutex_t thread0 = PTHREAD_MUTEX_INITIALIZER;
pthread_t thread0_id = 0;
int mainMultiThread()
{
  // Thread variables
  pthread_t sobel1, sobel2;

  // Set up a barrier to synchronize both threads at the end of runSobel
  pthread_barrier_init(&endSobel, NULL, 2);

  // Call threads
  int ret;
  if ( (ret = pthread_create( &sobel1, NULL, runSobelMT, NULL)) ){
    printf("Thread creation failed: %d\n", ret);
    exit(1);
  }
  if ( (ret = pthread_create( &sobel2, NULL, runSobelMT, NULL)) ){
    printf("Thread creation failed: %d\n", ret);
    exit(1);
  }

  // Wait for them to finish
  pthread_join(sobel1, NULL);
  pthread_join(sobel2, NULL);

  // Destroy the barriers
  pthread_barrier_destroy(&endSobel);

  // Return ok if sobel returns correctly
  return 0;
}

int main(int argc, char **argv)
{
  parseOpts(argc, argv);

  if (opts.multiThreaded == 0) {
    mainSingleThread();
  }
  else if (opts.multiThreaded == 1) {
    mainMultiThread();
  }
  else {  // Invalid argument
   fprintf(stderr,"Usage: %s [-m]\n",argv[0]);
  }
  return 0;
}
