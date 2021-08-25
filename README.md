# md2html.awk
AWK script to convert a basic subset of MD to HTML.  

***NOTE** - Nested lists should be working.  Let me know if not.*

Only uses the parts of MD that I want to use, and with the syntax that I use.  Little or no handling for incorrect syntax.

Does not understand tables, only handles `# ` headers, blank lines close all open block elements, probably some other quirks.

Written to work with `awk version 20070501` that ships with macOS (at least up to Catalina).

Does not generate the \<html\>, \<head\>, and \<body\> tags.  Use [makesite.awk](https://github.com/quBASIC/makesite.awk) or similar to generate that stuff.

## Usage
```
awk -f md2html.awk filename.md > filename.html
```

Alternately, set `md2html.awk` as executable:
```
chmod +x md2html.awk
./md2html.awk filename.md > filename.html
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

  

## Thoughts on the Implementation
I tried to keep the implementation as portable as possible by avoiding `gensub()` and other features from GAWK.

General plan is unexciting:
- Define a function `rec_close()` that takes a number representing an index into `blocks`.  Function will close block elements starting with the one at `length(blocks)` and working backwards towards the provided index.
- Setup the only global in the BEGIN pattern:  
    - `blocks` - will be a string with the nesting order of the block elements in the current state.
- Process all lines of input in the empty pattern (by default applied to all lines). 
- Cleanup any open blocks in the END pattern with `rec_close(0)`.

The bold, italic, inline code, images, and links can be handled with no knowledge outside of the current line (after all of the block elements are handled).

## Notes on Specific Segments
Notes for future me (or whoever else might look at this code).

### Code Blocks
Initially used \<code\> on inline and block quotes, but switched block quotes to \<pre\>.  This is what GitHub's parser seems to do, and it made my CSS simpler in practice.

### Header
Matches any number of `#` followed by a space.  Conveniently, `RLENGTH-1` indicates the header level.

Replace the matched pattern with `<h(RLENGTH-1)>` and append `</h(RLENGTH-1)>` to the end of the line.

There might be italics, links, or other inline stuff in the line still so we should continue processing the line.

The else block catches the fact that we are not in a paragraph currently and starts one.  Turns out this is the only place this needs to happen if you are willing to have slightly more paragraphs than strictly necessary (nested inside of list items, etc).

This should probably test for a maximum length of six `#` in a row, but currently does not.

### Order Matters
Order matters in several places.  Some are trivial: blank lines and horizontal rules are processed as early as possible to skip further processing if the line matches.

Processing currently inside a code block, nested blockquotes/ul/ol, new code blocks, and headers in that order for a reason.  

If we are not currently in a \<code\> block, then we should continue processing further markdown.

This implementation strips off indents (4x spaces), `> `, `* `, and `1. `, etc as it goes. 

For inline elements, the regex pattern can be made much simpler if all bolds are handled first and then all italics.  

The same for images and links.  If links are matched first, then the regex has to match the non-! character to be sure it is not a link.  This could be fixed by shifting the `substr()` indexs around, but if images are processed first then the only remaining things MUST be links.
