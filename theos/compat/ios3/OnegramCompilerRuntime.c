#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

extern unsigned int __udivsi3(unsigned int, unsigned int);
extern int __divsi3(int, int);

unsigned int __udivmodsi4(unsigned int numerator, unsigned int denominator, unsigned int *remainder)
{
    unsigned int quotient = __udivsi3(numerator, denominator);
    if (remainder != 0)
        *remainder = numerator - quotient * denominator;
    return quotient;
}

int __divmodsi4(int numerator, int denominator, int *remainder)
{
    int quotient = __divsi3(numerator, denominator);
    if (remainder != 0)
        *remainder = numerator - quotient * denominator;
    return quotient;
}

void arc4random_buf(void *buffer, size_t length)
{
    unsigned char *bytes = (unsigned char *)buffer;
    while (length != 0)
    {
        unsigned int value = arc4random();
        size_t count = length < sizeof(value) ? length : sizeof(value);
        memcpy(bytes, &value, count);
        bytes += count;
        length -= count;
    }
}

uint32_t arc4random_uniform(uint32_t upper_bound)
{
    if (upper_bound < 2)
        return 0;

    uint32_t minimum = (uint32_t)(-upper_bound) % upper_bound;
    uint32_t value;
    do
    {
        value = arc4random();
    } while (value < minimum);

    return value % upper_bound;
}
