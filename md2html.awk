#!/usr/bin/awk -f

# md2html.awk
#
# Generate HTML output from MarkDown - v4
#
# Usage:
# awk -f md2html.awk filename.md > filename.html
# 
# #####################################################
#
# MarkDown's "standard" is a mess.  This script is for
# my own use, and only understands the opinionated and 
# minimal subset of MD that I actually use:
# **text** for bold, 
# *test* for italic,
# `some text` for inline code, 
# ![alt text](source url) for images,
# [text](destination url) for links,
# two spaces at  end of line forces line break,
# --- alone for horizontal rule,
# ``` above and below for a code block,
# > blockquote (can be nested "> > ..."),
# 1-6 #'s followed by a space for h1-6,
# 1. ordered list, 
# * unordered list (0-3 spaces before *, one after)
# #####################################################


# #####################################################
#                     Functions
# #####################################################
function rec_close(i, j) {
    if (length(blocks) > 0) {
        if (i < length(blocks)) {
            for (j = length(blocks); j > i; j--) {
                el = substr(blocks, length(blocks));

                if (el == "b") {
                    printf("</blockquote>");
                } else if (el == "c") {
                    printf("</pre>");
                } else if (el == "o") {
                    printf("</ol>");
                } else if (el == "u") {
                    printf("</ul>");
                } else if (el == "l") {
                    printf("</li>");
                } else {
                    printf("</p>");
                }

                sub(/[a-z]$/, "", blocks);
            }
        }
    } 
}



# #####################################################
#                     Patterns
# #####################################################
BEGIN {
    blocks = "";
}



# #####################################################
{
    # handle being inside a code block
    if (substr(blocks, length(blocks)) == "c" ) {
        for (i = 0; i < length(blocks)-1; i++) {
        # we are assuming that the file is well-
        # formed here... a dangerous assumption
            sub(/^((    )|(> ))/, "");
        }
        
    
        if ($0 ~ /^```$/) {
            print("</pre>");
            sub(/c$/, "", blocks);
        } else {       
            # minimal escaping to make HTML not spaz
            gsub("&", "\\&amp;");
            gsub(/\\?</, "\\&lt;");
            print($0);
        }        
        # no further processing necessary in code block
        next;
    }
    
    # blank line
    if ($0 ~ /^$/) {
        rec_close(0);
        next;
    }   
 
    # hr
    if ($0 ~ /^( )*---+( )*$/) {
        if (substr(blocks, length(blocks)) == "p") {
            printf("</p>");
            sub(/[a-z]$/, "", blocks);
        }
        print("<hr>");
        next;
    }

    # are we still in a block?
    if (length(blocks) > 0) {
        # awk string indexing is gross
	for (i = 1; i <= length(blocks); i++) {
            el = substr(blocks, i, 1);

            if (el == "b") {
                if (sub(/^(> )/, "") == 1) {
                    continue;
                } else {
                    rec_close(i);
                }
            } else {
                if (el == "o" || el == "u") {
                    if (sub(/^(    )/, "") == 1) {
                        continue;
                    } else {
                        # is it the right kind of list?
                        if (el=="u" && sub(/^( )?( )?( )?(\*|\+|-)( )+/, "") == 1 ) {
                            rec_close(i);
                            printf("<li>");
                            blocks = blocks "l";
                        } else if (el=="o" && sub(/^( )*[0-9]+\.( )+/, "") == 1) {
                            rec_close(i);
                            printf("<li>");
                            blocks = blocks "l";
                        } else {
                            # must be something completely different
                            # close everything including this item
                            rec_close(i-1);
                        }
                    }
                }
            }
        }
    }
    # existing block elements should be handled
 
    # check for new block elements
    if (sub(/^(> )/, "") == 1) {
        if (substr(blocks, length(blocks)) == "p") {
            printf("</p>");
            sub(/[a-z]$/, "", blocks);
        }
        blocks = blocks "b";
        printf("<blockquote>");
    }

    # level of indention should not matter at this point
    # so ( )* instead of ( )? x3 to clean up whitespace
    if (sub(/^( )*(\*|\+|-)( )+/, "") == 1) {
        if (substr(blocks, length(blocks)) == "p") {
            printf("</p>");
            sub(/[a-z]$/, "", blocks);
        }
        if (substr(blocks, length(blocks)) == "l") {
            printf("</li>");
            sub(/[a-z]$/, "", blocks);
        }

        printf("<ul><li>");
        blocks = blocks "ul";
    } else if (sub(/^( )*[0-9]+\.( )+/, "") == 1) {
        if (substr(blocks, length(blocks)) == "p") {
            printf("</p>");
            sub(/[a-z]$/, "", blocks);
        }
        if (substr(blocks, length(blocks)) == "l") {
            printf("</li>");
            sub(/[a-z]$/, "", blocks);
        }

        printf("<ol><li>");
        blocks = blocks "ol";
    }




    # start a new code block
    if ($0 ~ /^```$/) {
        if (substr(blocks, length(blocks)) == "p") {
            printf("</p>");
            sub(/[a-z]$/, "", blocks);
        }

        print("<pre>");
        blocks = blocks "c";
        next;
    } 

        
    # ###### h1 - h6 ######
    if (match($0, /^#+ /)) {
        sub(/^#+( )*/, "");
        # also clear trailing #'s
        sub(/( )*#+$/, "");

        # insert anchors on headers
        a = $0;
        gsub(/( )/, "-", a);
        gsub(/[^a-zA-Z0-9_-]/, "", a);

        # do not want duplicate labels
        if (length(labels) > 0) {
            j = 0;
            for (i = 0; i < length(labels); i++) {
                #  this is mildly janky
                if (a == labels[i]) {
                    if (j == 0) {
                        a = a "-" ++j;
                    } else {
                        sub(/-[0-9]+$/, "-" ++j, a);
                    }
                }
            }
            labels[length(labels)] = a;
        } else {
            labels[0] = a;
        }
        a = "<a name='" tolower(a) "'></a>";
        
        $0 = "<h" RLENGTH-1 ">" a $0 "</h" RLENGTH-1 ">";        
    } else {
        # no other block elements match, start a <p>
        if (substr(blocks, length(blocks)) != "p") {
                blocks = blocks "p";
                printf("<p>");
        }
    }

    
    # Process inline elements
    
    # **bold** 
    while (match($0, /\*\*[^(**)]+\*\*/)) {
	    a = substr($0, 1, RSTART-1);
        b = substr($0, RSTART+2,RLENGTH-4);
        c = substr($0, RSTART+RLENGTH);
        $0 = a "<strong>" b "</strong>" c;
    }
    
    # *italic*
    while (match($0, /\*[^*]+\*/)) {
        a = substr($0, 1, RSTART-1);
        b = substr($0, RSTART+1,RLENGTH-2);
        c = substr($0, RSTART+RLENGTH);
        $0 = a "<em>" b "</em>" c;
    }

    # `inline code`
    while (match($0, /\`[^`]+\`/)){
        a = substr($0, 1, RSTART-1);
        b = substr($0, RSTART+1,RLENGTH-2);
        c = substr($0, RSTART+RLENGTH);

        # need to escape HTML in code segments
        gsub("&", "\\&amp;", b);
        gsub(/\\?</, "\\&lt;", b);

        $0 = a "<code>" b "</code>" c;
    }
    
    # ![image](URL)
        while (match($0, /!\[.*\]\(.*\)/)) {
            a = substr($0, 1, RSTART-1);
            c = substr($0, RSTART+RLENGTH);
            split(substr($0, RSTART+2, RLENGTH-3), arr, /\]\(/);
            $0 = a "<img src=\"" arr[2] "\">" arr[1] "</img>" c;
    }
                            
    # [links](URL)
        while (match($0, /\[.*\]\(.*\)/)) {
            a = substr($0, 1, RSTART-1);
            c = substr($0, RSTART+RLENGTH);
            split(substr($0, RSTART+1, RLENGTH-2), arr, /\]\(/);
            $0 = a "<a href=\"" arr[2] "\">" arr[1] "</a>" c;        
    }

    # line break
    gsub(/(  )$/, "<br>");
    
    print($0);
}



# #####################################################
END {
    # clean up anything still open    
    rec_close(0);
}
