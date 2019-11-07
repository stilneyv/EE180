/**********************************************************
* mergesort.c                                             *
*                                                         *
* This program sorts using a simple merge sort algorithm. *
* Written by Chris Copeland (chrisnc@stanford.edu)        *
**********************************************************/

#include "stdio.h"
#include "stdlib.h"

void mergesort(int *array, int n, int *temp_array);
void merge(int *array, int n, int *temp_array, int mid);
void copy_array(int *dst, int *src, int n);

int main() {
    int *nums, *temp_array, i, array_size;

    printf("How many elements to be sorted? ");
    int tokens_read = scanf("%d", &array_size);
    if (tokens_read != 1) {
        printf("Could not read array size.\n");
        exit(1);
    }

    nums = (int *) malloc(sizeof(int) * array_size);
    temp_array = (int *) malloc(sizeof(int) * array_size);

    for (i = 0; i < array_size; i++) {
        printf("Enter next element: ");
        tokens_read = scanf("%d", &(nums[i]));
        if (tokens_read != 1) {
            printf("Could not read the next element.\n");
            exit(1);
        }
    }

    mergesort(nums, array_size, temp_array);

    printf("The sorted list is:\n");
    for (i = 0; i < array_size; i++)
        printf("%d ", nums[i]);
    printf("\n");
    free(nums);
    free(temp_array);
}

void mergesort(int *array, int n, int *temp_array)
{
    if (n < 2)
        return;
    int mid = n/2;
    mergesort(array, mid, temp_array);
    mergesort(array + mid, n - mid, temp_array);
    merge(array, n, temp_array, mid);
}

void merge(int *array, int n, int *temp_array, int mid)
{
    int tpos = 0, lpos = 0, rpos = 0, rn = n - mid, *rarr = array + mid;
    while (lpos < mid && rpos < rn) {
        if (array[lpos] < rarr[rpos])
            temp_array[tpos++] = array[lpos++];
        else
            temp_array[tpos++] = rarr[rpos++];
    }
    if (lpos < mid)
        copy_array(temp_array + tpos, array + lpos, mid - lpos);
    if (rpos < rn)
        copy_array(temp_array + tpos, rarr + rpos, rn - rpos);
    copy_array(array, temp_array, n);
}

void copy_array(int *dst, int *src, int n) {
    int i;
    for (i = 0; i < n; i++)
        dst[i] = src[i];
}
