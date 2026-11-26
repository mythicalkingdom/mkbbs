1 REM The BBS for a BASIC script: paste these lines at the top (line numbers 1-9 are left for them), then use the names.
2 DEF FNQ(C$)=VAL(HOST$(C$)) : REM FNQ("msg.list 1")  runs a command: the number of lines of the answer
3 DEF FNF$(N,F$)=HOST$("field "+MID$(STR$(N),2)+" "+F$) : REM FNF$(1,"from")  a field of record N
4 DEF FNL$(N)=HOST$("line "+MID$(STR$(N),2)) : REM FNL$(0)  a whole line (0: the names of the fields)
5 DEF FNV$(C$)=HOST$("="+C$) : REM FNV$("system.info")  the first record, or the one value of a command
