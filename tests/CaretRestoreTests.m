#import <Cocoa/Cocoa.h>
#import <stdio.h>
#import "NoteLayout.h"

/* Build and run from the project root:
   clang -framework Cocoa -I. tests/CaretRestoreTests.m NoteLayout.m -o /tmp/CaretRestoreTests && /tmp/CaretRestoreTests */

static int gFailures = 0;

static void expectTrue(BOOL cond, const char *what) {
	if (!cond) {
		fprintf(stderr, "FAIL %s\n", what);
		gFailures++;
	}
}

static NSRange none(void) {
	return NSMakeRange(NSNotFound, 0);
}

int main(void) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[NSApplication sharedApplication];

	/* The selection a note is shown with, on its own. */
	NSRange caret = NSMakeRange(1516, 0);
	NSRange match = NSMakeRange(285, 3);
	expectTrue(NSEqualRanges(NVSelectionForShownNote(caret, 5000, match), caret), "a bare caret the note was left with comes back, even with a search match on screen");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(caret, 5000, none()), caret), "a bare caret comes back with no search on");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(NSMakeRange(40, 12), 5000, match), NSMakeRange(40, 12)), "a selected range comes back, even with a search match on screen");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(NSMakeRange(0, 0), 5000, match), NSMakeRange(0, 0)), "a caret saved at the very start is still a saved caret");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(none(), 5000, match), match), "a note never visited gets the search match on screen");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(none(), 5000, none()), NSMakeRange(0, 0)), "a note never visited, with no search, starts at the top");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(NSMakeRange(6000, 0), 5000, match), match), "a saved caret past the end of the note is dropped for the match");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(NSMakeRange(4990, 20), 5000, none()), NSMakeRange(0, 0)), "a saved selection running past the end is dropped for the top");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(NSMakeRange(5000, 0), 5000, none()), NSMakeRange(5000, 0)), "a caret at the very end is kept");
	expectTrue(NSEqualRanges(NVSelectionForShownNote(none(), 10, NSMakeRange(8, 5)), NSMakeRange(0, 0)), "a match that does not fit the note is not used");

	/* The whole return to a note: a 200-line note left with the caret on word 4
	   of line 50, shown again while a search has a match far from there. */
	NSRect frame = NSMakeRect(0, 0, 420, 280);
	NSWindow *window = [[NSWindow alloc] initWithContentRect:frame styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:frame];
	[scroll setHasVerticalScroller:YES];
	[[window contentView] addSubview:scroll];
	NSTextView *text = [[NSTextView alloc] initWithFrame:[[scroll contentView] bounds]];
	[text setVerticallyResizable:YES];
	[text setHorizontallyResizable:NO];
	[text setMinSize:NSMakeSize(0, NSHeight(frame))];
	[text setMaxSize:NSMakeSize(100000, 10000000)];
	[[text textContainer] setWidthTracksTextView:YES];
	[[text textContainer] setHeightTracksTextView:NO];
	[scroll setDocumentView:text];

	NSMutableString *body = [NSMutableString string];
	NSUInteger line, wordFourOfLineFifty = NSNotFound;
	for (line = 1; line <= 200; line++) {
		if (line == 50)
			wordFourOfLineFifty = [body length] + [@"one two three " length];
		[body appendFormat:@"one two three four line %03lu\n", (unsigned long)line];
	}
	[text setString:body];
	NVLayOutEntireNote(text);

	NSRange left = NSMakeRange(wordFourOfLineFifty, 0);
	NSUInteger leftTop = [body lineRangeForRange:NSMakeRange(wordFourOfLineFifty, 0)].location;
	NSRange farMatch = [body rangeOfString:@"line 180"];
	NSUInteger length = [body length];

	NVScrollCharIndexToTop(text, leftTop);
	NSRange shown = NVScrollToShowNearestRange(text, @[[NSValue valueWithRange:farMatch]]);
	expectTrue(shown.location == farMatch.location, "the search match far below is brought on screen");
	NSRange selection = NVSelectionForShownNote(left, length, shown);
	[text setSelectedRange:selection];
	expectTrue(NSEqualRanges([text selectedRange], left), "coming back to the note puts the caret on word 4 of line 50");

	NVScrollCharIndexToTop(text, leftTop);
	shown = NVScrollToShowNearestRange(text, nil);
	selection = NVSelectionForShownNote(left, length, shown);
	[text setSelectedRange:selection];
	expectTrue(NSEqualRanges([text selectedRange], left), "with no search, the caret is on word 4 of line 50");
	expectTrue(NVFirstVisibleCharIndex(text) == leftTop, "and line 50 is at the top, where the note was left");

	if (gFailures)
		fprintf(stderr, "%d failure(s)\n", gFailures);
	else
		printf("CaretRestoreTests: all passed\n");
	[text release];
	[scroll release];
	[window release];
	[pool drain];
	return gFailures ? 1 : 0;
}
