#! /usr/bin/awk -f

# md2html.awk
#
# Generate HTML output from MarkDown - v2
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
# check if in paragraph and close if so
function pclose() {
    if (para > 0) {
        para = 0;
        printf("</p>");
    }
}



# #####################################################
# run prior to processing any text
#
BEGIN {
    # setup state variables
    code = 0;
    para = 0;
    quot = 0;
}



# #####################################################
# process input line by line
#
{   
    # block quotes
    if (match($0, /^(> )+/)) {
        # still at the same quote depth?
        while (quot < RLENGTH/2 && code==0) {
            pclose();
            printf("<blockquote>");
            quot++;
        }
        
        while (quot > RLENGTH/2 && code==0) {
            pclose();
            printf("</blockquote>");
            quot--;
        }
        
        sub(/^(> )+/, "")
    } 

    # blank lines
    if (match($0, /^( )*$/) && code==0) {
        # if currently in paragraph, end paragraph 
        pclose();

        # dislike this placement, but best option
        # that I can currently find for it
        while (quot > 0) {
            quot--;
            printf("</blockquote>");
        }

        # skip further processing of blank lines
        next;
    }
    
    # ampersand must be escaped first
    gsub("&", "\\&amp;")

    # escape -'s before checking for hr
    gsub(/\\-/, "\\\&#45;");
    
    # horizontal rule
    if (match($0, /^\-\-\-$/) && para==0 && code==0) {
        printf("<hr>");
        next;
    }

    # do the rest of the escape sequences
    gsub(/\\\!/, "\\\&#33;");
    gsub(/\\\#/, "\\\&#35;");
    gsub(/\\\*/, "\\\&#42;");
    gsub(/\\\+/, "\\\&#43;");
    gsub(/\\\./, "\\\&#46;");
    gsub(/\\?</, "\\&#60;");
    gsub(/\\?>/, "\\&#62;");
    gsub(/\\\[/, "\\\&#91;");
    gsub(/\\\\/, "\\\&#92;");
    gsub(/\\\]/, "\\\&#93;");
    gsub(/\\_/,  "\\\&#95;");
    gsub(/\\`/,  "\\\&#96;");
    gsub(/\\\{/, "\\\&#123;");
    gsub(/\\\|/, "\\\&#124;");
    gsub(/\\\}/, "\\\&#125;");
        
    # code blocks
    if (match($0, /^(\> )*\`\`\`$/)) {
        if (code > 0) {
            code = 0;
            printf("</pre>");
            next;
        } else {
            pclose();
            code = 1;
            printf("<pre>");
            next;
        }
    }
    
    # skip MD processing inside of code blocks
    if (code > 0) {
        print($0);
        next;
    }
    
    # headers
    if (match($0, /^\#+ /)) { 
        pclose();
        $0 = "<h" RLENGTH-1 ">" substr($0, RLENGTH+1) "</h" RLENGTH-1 ">";
    } else {
        # start paragraphs
        if (para == 0) {
            para = 1;
            $0 = "<p>" $0;
        }
    }

    # bold 
    while (match($0, /\*\*[^(**)]+\*\*/))
        $0 = substr($0, 1, RSTART-1) "<strong>" substr($0, RSTART+2,RLENGTH-4) "</strong>" substr($0, RSTART+RLENGTH)
    
    # italic
    while (match($0, /\*[^*]+\*/))
        $0 = substr($0, 1, RSTART-1) "<em>" substr($0, RSTART+1,RLENGTH-2) "</em>" substr($0, RSTART+RLENGTH)

    # inline code
    while (match($0, /\`[^`]+\`/))
        $0 = substr($0, 1, RSTART-1) "<code>" substr($0, RSTART+1,RLENGTH-2) "</code>" substr($0, RSTART+RLENGTH)
    
    # images
    while (match($0, /!\[.*\]\(.*\)/)) {
        split(substr($0, RSTART+2, RLENGTH-3), a, /\]\(/);
        $0 = substr($0, 1, RSTART-1) "<img src=\"" a[2] "\">" a[1] "</img>" substr($0, RSTART+RLENGTH);
    }

    # links
    while (match($0, /\[.*\]\(.*\)/)) {
        split(substr($0, RSTART+1, RLENGTH-2), a, /\]\(/);
        $0 = substr($0, 1, RSTART-1) "<a href=\"" a[2] "\">" a[1] "</a>" substr($0, RSTART+RLENGTH);        
    }

    # line break
    gsub(/(  )$/, "<br>");

    # processing done, print the line
    print($0);
}



# #####################################################
# cleanup
#
END {    
    # still in a code block?
    if (code > 0)
        printf("</code>");

    # probably still in a paragraph
    pclose();
    
    # still in a blockquote?
    while (quot > 0) {
        printf("</blockquote>");
        quot--;
    }
}
