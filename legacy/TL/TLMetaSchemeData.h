#ifndef TG_LEGACY_TL_TLMETASCHEMEDATA_H
#define TG_LEGACY_TL_TLMETASCHEMEDATA_H

#import "TLMetaScheme.h"

#include <stdint.h>

typedef struct TLMetaSchemeParamEntry
{
    uint32_t name;
    uint32_t type;
} TLMetaSchemeParamEntry;

typedef struct TLMetaSchemeEntry
{
    int32_t signature;
    uint32_t name;
    uint32_t type;
    uint32_t paramsOffset;
    uint32_t paramsCount;
} TLMetaSchemeEntry;

typedef struct TLMetaSchemeTable
{
    const char *strings;
    const TLMetaSchemeEntry *types;
    uint32_t typesCount;
    const TLMetaSchemeEntry *methods;
    uint32_t methodsCount;
    const TLMetaSchemeParamEntry *params;
    uint32_t paramsCount;
} TLMetaSchemeTable;

typedef struct TLMetaClassEntry
{
    int32_t key;
    uint32_t className;
} TLMetaClassEntry;

typedef struct TLMetaClassTable
{
    const char *classNames;
    const TLMetaClassEntry *objectClasses;
    uint32_t objectClassesCount;
    const TLMetaClassEntry *vectorClasses;
    uint32_t vectorClassesCount;
} TLMetaClassTable;

const TLMetaSchemeTable *TLgetMetaSchemeTable();
TLScheme *TLgetMetaScheme();
const TLMetaClassTable *TLgetMetaClassTable();

#endif
