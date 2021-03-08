// TEST_CONFIG MEM=mrc

#include "test.h"
#include "testroot.i"

static size_t LOTS;

@interface Deallocator : TestRoot @end
@implementation Deallocator

-(void)dealloc 
{
    id o = self;


    testprintf("Retain/release during dealloc\n");

    testassertequal([o retainCount], 0);
    [o retain];
    testassertequal([o retainCount], 0);
    [o release];
    testassertequal([o retainCount], 0);

    [super dealloc];
}

@end

size_t clz(uintptr_t isa) {
    if (sizeof(uintptr_t) == 4)
        return __builtin_clzl(isa);
    testassert(sizeof(uintptr_t) == 8);
    return __builtin_clzll(isa);
}

int main()
{
    Deallocator *o = [Deallocator new];
    size_t rc = 1;

    [o retain];

    uintptr_t isa = *(uintptr_t *)o;
    if (isa & 1) {
        // Assume refcount in high bits.
        LOTS = 1 << (4 + clz(isa));
        testprintf("LOTS %zu via cntlzw\n", LOTS);
    } else {
        LOTS = 0x1000000;
        testprintf("LOTS %zu via guess\n", LOTS);
    }

    [o release];    


    testprintf("Retain a lot\n");

    testassert(rc == 1);
    testassert([o retainCount] == rc);
    do {
        [o retain];
        if (rc % 0x100000 == 0) testprintf("%zx/%zx ++\n", rc, LOTS);
    } while (++rc < LOTS);

    testassert([o retainCount] == rc);

    do {
        [o release];
        if (rc % 0x100000 == 0) testprintf("%zx/%zx --\n", rc, LOTS);
    } while (--rc > 1);

    testassert(rc == 1);
    testassert([o retainCount] == rc);


    testprintf("tryRetain a lot\n");

    id w;
    objc_storeWeak(&w, o);
    testassert(w == o);

    testassert(rc == 1);
    testassert([o retainCount] == rc);
    do {
        objc_loadWeakRetained(&w);
        if (rc % 0x100000 == 0) testprintf("%zx/%zx ++\n", rc, LOTS);
    } while (++rc < LOTS);

    testassert([o retainCount] == rc);

    do {
        [o release];
        if (rc % 0x100000 == 0) testprintf("%zx/%zx --\n", rc, LOTS);
    } while (--rc > 1);

    testassert(rc == 1);
    testassert([o retainCount] == rc);
    
    testprintf("dealloc\n");

    testassert(TestRootDealloc == 0);
    testassert(w != nil);
    [o release];
    testassert(TestRootDealloc == 1);
    testassert(w == nil);

    succeed(__FILE__);
}
