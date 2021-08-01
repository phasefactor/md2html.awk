# md2html.awk
AWK script to convert a basic subset of MD to HTML.

Currently generates the \<html\>, \<head\>, and \<body\> tags.  Possibly better if this is handled separately so that this can process MD and the HTML can be injected into the \<body\> of a template.

## Usage
```
awk -f md2html.awk filename.md > filename.html
```

## Supported Syntax
- \*\*bold\*\*
- \*italic\*
- \`inline code\`
- \!\[alt text\]\(source URL\)
- \[link text\]\(destination URL\)
- \-\-\- alone, after empty line for horizontal rule
- \`\`\` above and below a code block
- \> blockquotes
- two spaces at end of line forces line break

## HTML \<head\> Section
By default the \<head\> is empty.  Manually update `md2html.awk` with your \<style\>'s, etc. 

Later I might add a command line argument to specify a file to insert.

## Thoughts on the Implementation
I tried to keep the implementation as portable as possible by avoiding `gensub()` and other features from GAWK.

General plan is unexciting:
- Handle the HTML preamble in the BEGIN pattern.
- Process all lines of input in the empty pattern (by default applied to all lines). 
- Close out the \<body\> and \<html\> tags in the END pattern.

The bold, italic, inline code, images, and links can be handled with no knowledge outside the current line.

Whether the parser is currently in a paragraph or code block needs to be tracked by a state variable (0 and 1 are used as Booleans for this).

Multiple levels of blockquote are supported, so the state variable is an integer tracking the current level of nesting.

The only action that happened frequently enough to deserve a function was checking if we were in a paragraph and inserting the closing tag if so.

## Notes on Specific Segments
Notes for future me (or whoever else might look at this code).

### Blockquote
Initially match any number of `> ` at the beginning of the current line.  Conveniently, `RLENGTH/2` tells us how many levels of blockquotes we have.

Compare that to `quot`.  If we are too low, then print a new \<blockquote\>.  If we are too high, then print a \<\/blockquote\>.  Then update `quot`.

The else-if block triggers on the line after the blockquote ends.  So print \<\/blockquote\> and update `quot`.

### Header
Matches any number of `#` followed by a space.  Conveniently, `RLENGTH-1` indicates the header level.

Replace the matched pattern with `<h(RLENGTH-1)>` and append `</h(RLENGTH-1)>` to the end of the line.

There might be italics, links, or other inline stuff in the line still so we should continue processing the line.

The else block catches the fact that we are not in a paragraph currently and starts one.  Turns out this is the only place this needs to happen.

This should probably test for a maximum length of six `#` in a row, but currently does not.

### Order Matters
Order matters in several places.  Some are trivial: blank lines and horizontal rules are processed as early as possible to skip further processing if the line matches.

Processing blockquotes, code blocks, and headers in that order for a reason.  Blockquotes allow markdown inside, so \<code\> needs to be processed after \<blockquote\>.  If we are not in a \<code\> block, then we should continue processing further markdown.

The regex pattern can be made much simpler if all bolds are handled first and then all italics.  

The same for images and links.  If links are matched first, then the regex has to match the non-! character to be sure it is not a link.  This could be fixed by shifting the `substr()` indexs around, but if images are processed first then the only remaining things MUST be links.


