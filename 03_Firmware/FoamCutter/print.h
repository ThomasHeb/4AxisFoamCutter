/* This code was initially inspired by the wiring_serial module by David A. Mellis which
   used to be a part of the Arduino project. */

#ifndef print_h
#define print_h

void printString(const char *s);

void printPgmString(const char *s);

void printInteger(long n);

void print_uint8_base2(uint8_t n);

void printFloat(float n);

#endif
