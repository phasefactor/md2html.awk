#!/usr/bin/awk -f

# md2html.awk
#
# Generate HTML output from MarkDown - v3
#
# Usage:
# awk -f md2html.awk filename.md > filename.html
# 
# #####################################################
#
# Understands most common MD:
#
# **text** for bold, *test* for italic,
# ![alt text](source url) for images,
# [text](destination url) for links,
# two spaces at  end of line forces line break,
# `some text` for code, --- alone for horizontal rule,
# ``` above and below for a code block,
# > indicates a blockquote (can be nested "> > ...")
#
# #####################################################



# #####################################################
# functions for common actions
#






# #####################################################
# run prior to processing any text
#
BEGIN {
    bt[1] = "";
    bs    = 0;
    qd    = 0;
    il    = 0;
    nl    = 0;
}



# #####################################################
# process input line by line
#
{
    # minimal amount of escaping to make HTML not spaz
    gsub("&", "\\&amp;");
    gsub(/\\?</, "\\&lt;");

    if (bt[length(bt)] == "pre") {
        if (qd > 0)
            for (i = 0; i < qd; i++)
                sub(/^(> )/, "");    
        if ($0 ~ /^```$/) {
            print("</pre>");
            delete bt[length(bt)];            
        } else {
            print($0);
        }        
        next;
    }

    if (match($0, /^(> )+/)) {
        if (qd != RLENGTH/2) {
            while (qd < RLENGTH/2) {        
                if (bt[length(bt)] == "p") {
                    print("</p>");
                   delete bt[length(bt)];
                }
            
                bt[(length(bt)+1)] = "blockquote";
                printf("<blockquote>");
                qd++;
            }
            while (qd > RLENGTH/2 && length(bt) > 1) {
                if (bt[length(bt)] == "blockquote") 
                    qd--;
                    
                print("</" bt[length(bt)] ">");
                delete bt[length(bt)];
            } 
        }
        
        for (i = 0; i < qd; i++)
            sub(/^(> )/, "");    
    } else if (qd > 0 && bs > 0) {
        # non-zero quote depth and blank lines skipped
        while (qd > 0 && length(bt) > 1) {
            if (bt[length(bt)] == "blockquote") 
                qd--;
                    
            print("</" bt[length(bt)] ">");
            delete bt[length(bt)];
        } 
    }


    if ($0 ~ /^( )*$/) {
        bs++;
        next;
    }
    
    # indenting four spaces continues many block elements
    if (match($0, /^(    )*/)) {
        il = RLENGTH/4;
        # clean-up all the extra spaces
        sub(/^(    )+/, "");
    } 

    
    if (il+1 < nl) {
        while (il < nl && bt[length(bt)] > 1) {
            if (bt[length(bt)] == "ul" || bt[length(bt)] == "ol") 
                nl--;
                    
            print("</" bt[length(bt)] ">");
            delete bt[length(bt)];
        }
    }
    

    if ($0 ~ /^```$/) {
        if (bt[length(bt)] == "p") {
            print("</p>");
            delete bt[length(bt)];
        }

        bt[(length(bt)+1)] = "pre";
        printf("<pre>");
        next;
    }


    if ($0 ~ /^( )*(\*|\+|-)( )+[^ ]/) {
        if (nl == il) {
            nl++;
            bs = 0;
            bt[(length(bt)+1)] = "ul";
            printf("<ul>");
        }
        
        if (bt[length(bt)] == "li") {
            print("</li><li>");
        } else if (bt[length(bt)] == "p") {
            print("</p></li><li>");
            delete bt[length(bt)];
        } else {
            bt[(length(bt)+1)] = "li";
            printf("<li>");
        }
        sub(/^( )*(\*|\+|-)( )+/, "");
    } else if ($0 ~ /^( )*[0-9]+\.( )+[^ ]/) {
        if (nl == il) {
            nl++;
            bs = 0;
            bt[(length(bt)+1)] = "ol";
            printf("<ol>");
        }
        
        if (bt[length(bt)] == "li") {
            print("</li><li>");
        } else {
            bt[(length(bt)+1)] = "li";
            printf("<li>");
        }
        sub(/^( )*[0-9]+\.( )+/, "");
    }
    
    if (nl > 0 && bs > 0 && il < nl) {
        while (nl > 0 && length(bt) > 1) {
            if (bt[length(bt)] == "ul" || bt[length(bt)] == "ol") 
                nl--;
                    
            print("</" bt[length(bt)] ">");
            delete bt[length(bt)];        
        }
    }
    
    # ###### h1 - h6 ######
    if (match($0, /^\#+ /)) { 
        if (bt[length(bt)] == "p") {
            print("</p>");
            delete bt[length(bt)];
        }
    	sub(/( )*#+$/, "");
        $0 = "<h" RLENGTH-1 ">" substr($0, RLENGTH+1) "</h" RLENGTH-1 ">";
    } else {
        # start paragraphs
        if (bt[length(bt)] != "p" && bt[length(bt)] != "li" || il > 0 || (bt[length(bt)] == "p" && bs > 0)) {
                if (bt[length(bt)] == "p") {
                    print("</p>");
                   delete bt[length(bt)];
                }
            

             bt[(length(bt)+1)] = "p";
             printf("<p>");            
        }
    }

    # **bold** 
    while (match($0, /\*\*[^(**)]+\*\*/))
        $0 = substr($0, 1, RSTART-1) "<strong>" substr($0, RSTART+2,RLENGTH-4) "</strong>" substr($0, RSTART+RLENGTH)
    
    # *italic*
    while (match($0, /\*[^*]+\*/))
        $0 = substr($0, 1, RSTART-1) "<em>" substr($0, RSTART+1,RLENGTH-2) "</em>" substr($0, RSTART+RLENGTH)

    # `inline code`
    while (match($0, /\`[^`]+\`/))
        $0 = substr($0, 1, RSTART-1) "<code>" substr($0, RSTART+1,RLENGTH-2) "</code>" substr($0, RSTART+RLENGTH)
    
    # ![image](URL)
    while (match($0, /!\[.*\]\(.*\)/)) {
        split(substr($0, RSTART+2, RLENGTH-3), a, /\]\(/);
        $0 = substr($0, 1, RSTART-1) "<img src=\"" a[2] "\">" a[1] "</img>" substr($0, RSTART+RLENGTH);
    }

    # [links](URL)
    while (match($0, /\[.*\]\(.*\)/)) {
        split(substr($0, RSTART+1, RLENGTH-2), a, /\]\(/);
        $0 = substr($0, 1, RSTART-1) "<a href=\"" a[2] "\">" a[1] "</a>" substr($0, RSTART+RLENGTH);        
    }

    # line break
    gsub(/(  )$/, "<br>");

    
    # reset blank lines skipped
    bs = 0;
    
    print($0);
}



# #####################################################
# cleanup
#
END {
    while (bt[length(bt)] > 1) {
        printf("</" bt[length(bt)] ">");
        delete bt[length(bt)];        
    }
}
