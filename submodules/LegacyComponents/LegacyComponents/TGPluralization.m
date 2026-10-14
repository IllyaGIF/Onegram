#import "TGPluralization.h"

TGPluralFormValue TGPluralForm(unsigned int lc, int n) {
    switch (lc) {
        
        case 0x6c74:
        if (((n % 10) == 1) && (((n % 100) < 11 || (n % 100) > 19)))
        return TGPluralFormOne;
        if ((((n % 10) >= 2 && (n % 10) <= 9)) && (((n % 100) < 11 || (n % 100) > 19)))
        return TGPluralFormFew;
        break;
        
        case 0x6c76:
        if (n == 0)
        return TGPluralFormZero;
        if (((n % 10) == 1) && ((n % 100) != 11))
        return TGPluralFormOne;
        break;
        
        case 0x6379:
        if (n == 2)
        return TGPluralFormTwo;
        if (n == 3)
        return TGPluralFormFew;
        if (n == 0)
        return TGPluralFormZero;
        if (n == 1)
        return TGPluralFormOne;
        if (n == 6)
        return TGPluralFormMany;
        break;
        
        case 0x6265:
        case 0x6273:
        case 0x6872:
        case 0x7275:
        case 0x7368:
        case 0x7372:
        case 0x756b:
        if (((n % 10) == 1) && ((n % 100) != 11))
        return TGPluralFormOne;
        if ((((n % 10) >= 2 && (n % 10) <= 4)) && (((n % 100) < 12 || (n % 100) > 14)))
        return TGPluralFormFew;
        if (((n % 10) == 0) || (((n % 10) >= 5 && (n % 10) <= 9)) || (((n % 100) >= 11 && (n % 100) <= 14)))
        return TGPluralFormMany;
        break;
        
        case 0x6b7368:
        if (n == 0)
        return TGPluralFormZero;
        if (n == 1)
        return TGPluralFormOne;
        break;
        
        case 0x736869:
        if ((n >= 2 && n <= 10))
        return TGPluralFormFew;
        if ((n >= 0 && n <= 1))
        return TGPluralFormOne;
        break;
        
        case 0x6865:
        if (n == 2)
        return TGPluralFormTwo;
        if (n == 1)
        return TGPluralFormOne;
        if ((n != 0) && ((n % 10) == 0))
        return TGPluralFormMany;
        break;
        
        case 0x6373:
        case 0x736b:
        if (n == 1)
        return TGPluralFormOne;
        if ((n >= 2 && n <= 4))
        return TGPluralFormFew;
        break;
        
        case 0x6272:
        if ((n != 0) && ((n % 1000000) == 0))
        return TGPluralFormMany;
        if (((n % 10) == 1) && (((n % 100) != 11) && ((n % 100) != 71) && ((n % 100) != 91)))
        return TGPluralFormOne;
        if (((n % 10) == 2) && (((n % 100) != 12) && ((n % 100) != 72) && ((n % 100) != 92)))
        return TGPluralFormTwo;
        if ((((n % 10) >= 3 && (n % 10) <= 4) || ((n % 10) == 9)) && (((n % 100) < 10 || (n % 100) > 19) && ((n % 100) < 70 || (n % 100) > 79) && ((n % 100) < 90 || (n % 100) > 99)))
        return TGPluralFormFew;
        break;
        
        case 0x736c:
        if ((n % 100) == 2)
        return TGPluralFormTwo;
        if ((n % 100) == 1)
        return TGPluralFormOne;
        if (((n % 100) >= 3 && (n % 100) <= 4))
        return TGPluralFormFew;
        break;
        
        case 0x6c6167:
        if (n == 0)
        return TGPluralFormZero;
        if (((n >= 0 && n <= 2)) && (n != 0) && (n != 2))
        return TGPluralFormOne;
        break;
        
        case 0x706c:
        if (n == 1)
        return TGPluralFormOne;
        if ((((n % 10) >= 2 && (n % 10) <= 4)) && (((n % 100) < 12 || (n % 100) > 14)))
        return TGPluralFormFew;
        if (((n != 1) && (((n % 10) >= 0 && (n % 10) <= 1))) || (((n % 10) >= 5 && (n % 10) <= 9)) || (((n % 100) >= 12 && (n % 100) <= 14)))
        return TGPluralFormMany;
        break;
        
        case 0x6764:
        if ((n == 2) || (n == 12))
        return TGPluralFormTwo;
        if ((n == 1) || (n == 11))
        return TGPluralFormOne;
        if ((n >= 3 && n <= 10) || (n >= 13 && n <= 19))
        return TGPluralFormFew;
        break;
        
        case 0x6776:
        if ((((n % 10) >= 1 && (n % 10) <= 2)) || ((n % 20) == 0))
        return TGPluralFormOne;
        break;
        
        case 0x6d6b:
        if (((n % 10) == 1) && (n != 11))
        return TGPluralFormOne;
        break;
        
        case 0x6d74:
        if (n == 1)
        return TGPluralFormOne;
        if (((n % 100) >= 11 && (n % 100) <= 19))
        return TGPluralFormMany;
        if ((n == 0) || (((n % 100) >= 2 && (n % 100) <= 10)))
        return TGPluralFormFew;
        break;
        
        case 0x6d6f:
        case 0x726f:
        if (n == 1)
        return TGPluralFormOne;
        if ((n == 0) || ((n != 1) && (((n % 100) >= 1 && (n % 100) <= 19))))
        return TGPluralFormFew;
        break;
        
        case 0x6761:
        if (n == 2)
        return TGPluralFormTwo;
        if (n == 1)
        return TGPluralFormOne;
        if ((n >= 3 && n <= 6))
        return TGPluralFormFew;
        if ((n >= 7 && n <= 10))
        return TGPluralFormMany;
        break;
        
        case 0x6666:
        case 0x6672:
        case 0x6b6162:
        if (((n >= 0 && n <= 2)) && (n != 2))
        return TGPluralFormOne;
        break;
        
        case 0x6975:
        case 0x6b77:
        case 0x7365:
        case 0x6e6171:
        case 0x736d61:
        case 0x736d69:
        case 0x736d6a:
        case 0x736d6e:
        case 0x736d73:
        if (n == 2)
        return TGPluralFormTwo;
        if (n == 1)
        return TGPluralFormOne;
        break;
        
        case 0x616b:
        case 0x616d:
        case 0x6268:
        case 0x6869:
        case 0x6c6e:
        case 0x6d67:
        case 0x7469:
        case 0x746c:
        case 0x7761:
        case 0x66696c:
        case 0x677577:
        case 0x6e736f:
        if ((n >= 0 && n <= 1))
        return TGPluralFormOne;
        break;
        
        case 0x747a6d:
        if (((n >= 0 && n <= 1)) || ((n >= 11 && n <= 99)))
        return TGPluralFormOne;
        break;
        
        case 0x6166:
        case 0x6267:
        case 0x626e:
        case 0x6361:
        case 0x6461:
        case 0x6465:
        case 0x6476:
        case 0x6565:
        case 0x656c:
        case 0x656e:
        case 0x656f:
        case 0x6573:
        case 0x6574:
        case 0x6575:
        case 0x6669:
        case 0x666f:
        case 0x6679:
        case 0x676c:
        case 0x6775:
        case 0x6861:
        case 0x6973:
        case 0x6974:
        case 0x6b6b:
        case 0x6b6c:
        case 0x6b73:
        case 0x6b75:
        case 0x6b79:
        case 0x6c62:
        case 0x6c67:
        case 0x6d6c:
        case 0x6d6e:
        case 0x6d72:
        case 0x6e62:
        case 0x6e64:
        case 0x6e65:
        case 0x6e6c:
        case 0x6e6e:
        case 0x6e6f:
        case 0x6e72:
        case 0x6e79:
        case 0x6f6d:
        case 0x6f72:
        case 0x6f73:
        case 0x7061:
        case 0x7073:
        case 0x7074:
        case 0x726d:
        case 0x736e:
        case 0x736f:
        case 0x7371:
        case 0x7373:
        case 0x7374:
        case 0x7376:
        case 0x7377:
        case 0x7461:
        case 0x7465:
        case 0x746b:
        case 0x746e:
        case 0x7473:
        case 0x7572:
        case 0x7665:
        case 0x766f:
        case 0x7868:
        case 0x7a75:
        case 0x617361:
        case 0x617374:
        case 0x62656d:
        case 0x62657a:
        case 0x627278:
        case 0x636767:
        case 0x636872:
        case 0x636b62:
        case 0x667572:
        case 0x677377:
        case 0x686177:
        case 0x6a676f:
        case 0x6a6d63:
        case 0x6b616a:
        case 0x6b6367:
        case 0x6b6b6a:
        case 0x6b7362:
        case 0x6d6173:
        case 0x6d676f:
        case 0x6e6168:
        case 0x6e6e68:
        case 0x6e796e:
        case 0x706170:
        case 0x726f66:
        case 0x72776b:
        case 0x736171:
        case 0x736568:
        case 0x737379:
        case 0x737972:
        case 0x74656f:
        case 0x746967:
        case 0x76756e:
        case 0x776165:
        case 0x786f67:
        if (n == 1)
        return TGPluralFormOne;
        break;
        
        case 0x6172:
        if (n == 2)
        return TGPluralFormTwo;
        if (n == 1)
        return TGPluralFormOne;
        if (n == 0)
        return TGPluralFormZero;
        if (((n % 100) >= 3 && (n % 100) <= 10))
        return TGPluralFormFew;
        if (((n % 100) >= 11 && (n % 100) <= 99))
        return TGPluralFormMany;
        break;
    }
    
    return TGPluralFormOther;
}
