//
//	 ______    ______    ______    
//	/\  __ \  /\  ___\  /\  ___\   
//	\ \  __<  \ \  __\_ \ \  __\_ 
//	 \ \_____\ \ \_____\ \ \_____\ 
//	  \/_____/  \/_____/  \/_____/ 
//
//	Copyright (c) 2012 BEE creators
//	http://www.whatsbug.com
//
//	Permission is hereby granted, free of charge, to any person obtaining a
//	copy of this software and associated documentation files (the "Software"),
//	to deal in the Software without restriction, including without limitation
//	the rights to use, copy, modify, merge, publish, distribute, sublicense,
//	and/or sell copies of the Software, and to permit persons to whom the
//	Software is furnished to do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in
//	all copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//	FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//	IN THE SOFTWARE.
//
//
//  Bee_DebugMemoryBoard.h
//

#if __BEE_DEBUGGER__

#import <QuartzCore/QuartzCore.h>
#import "Bee_DebugMemoryModel.h"
#import "Bee_DebugUtility.h"

#include <mach/mach.h>
#include <malloc/malloc.h>

#pragma mark -

@implementation BeeDebugMemoryModel

@synthesize usedBytes = _usedBytes; 
@synthesize totalBytes = _totalBytes;
@synthesize manualBytes = _manualBytes;
@synthesize manualBlocks = _manualBlocks;
@synthesize chartDatas = _chartDatas;
@synthesize upperBound = _upperBound;
@synthesize warningMode = _warningMode;

DEF_SINGLETION( BeeDebugMemoryModel )

- (void)load
{
	[super load];
	
	_chartDatas = [[NSMutableArray alloc] init];
	_manualBlocks = [[NSMutableArray alloc] init];

	_upperBound = 0.0f;

	[self observeTick];
}

- (void)unload
{
	[self unobserveTick];
	
	[_chartDatas removeAllObjects];
	[_chartDatas release];
	
	for ( NSNumber * block in _manualBlocks )
	{
		void * ptr = (void *)[block unsignedLongLongValue];
		NSZoneFree( NSDefaultMallocZone(), ptr );
		
		[_manualBlocks removeLastObject];
	}
	
	[super unload];
}

- (void)allocAll
{
	NSUInteger total = NSRealMemoryAvailable();
	
	for ( ;; )
	{
		if ( _manualBytes + 50 * M >= total )
			break;

		void * block = NSZoneCalloc( NSDefaultMallocZone(), 50, M );
		if ( nil == block )
		{
			block = NSZoneMalloc( NSDefaultMallocZone(), 50 * M );
		}
		
		if ( block )
		{			
			_manualBytes += 50 * M;			
			[_manualBlocks addObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long)block]];
		}
		else
		{
			break;
		}
	}
	
	[self handleTick:0.0f];
}

- (void)freeAll
{
	for ( NSNumber * block in _manualBlocks )
	{
		void * ptr = (void *)[block unsignedLongLongValue];
		NSZoneFree( NSDefaultMallocZone(), ptr );
	}
	
	[_manualBlocks removeAllObjects];
	
	[self handleTick:0.0f];
}

- (void)alloc50M
{
	void * block = NSZoneCalloc( NSDefaultMallocZone(), 50, M );
	if ( nil == block )
	{
		block = NSZoneMalloc( NSDefaultMallocZone(), 50 * M );
	}
	
	if ( block )
	{
		_manualBytes += 50 * M;
		[_manualBlocks addObject:[NSNumber numberWithUnsignedLongLong:(unsigned long long)block]];
	}
	
	[self handleTick:0.0f];
}

- (void)free50M
{
	NSNumber * block = [_manualBlocks lastObject];
	if ( block )
	{
		void * ptr = (void *)[block unsignedLongLongValue];
		NSZoneFree( NSDefaultMallocZone(), ptr );
		
		[_manualBlocks removeLastObject];
	}
	
	[self handleTick:0.0f];
}

- (void)toggleWarning
{
	_warningMode = _warningMode ? NO : YES;
	
	[self handleTick:0.0f];	
}

- (void)handleTick:(NSTimeInterval)elapsed
{
	struct mstats stat = mstats();
	
	_usedBytes = stat.bytes_used;
	_totalBytes = NSRealMemoryAvailable();
	
	[_chartDatas addObject:[NSNumber numberWithUnsignedLongLong:_usedBytes]];
	[_chartDatas keepTail:MAX_MEMORY_HISTORY];

	_upperBound = 0.0f;

	for ( NSNumber * n in _chartDatas )
	{
		if ( [n intValue] > _upperBound )
		{
			_upperBound = [n intValue];
		}
	}
	
	if ( _warningMode )
	{
		[[UIApplication sharedApplication] performSelector:@selector(_performMemoryWarning)];		
	}
}

@end

#endif	// #if __BEE_DEBUGGER__
