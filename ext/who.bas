10 REM Who is on line, from a BASIC script:  mk -x ext/who.bas
20 DEF FNQ(C$)=VAL(HOST$(C$))
30 DEF FNF$(N,F$)=HOST$("field "+MID$(STR$(N),2)+" "+F$)
40 N = FNQ("node.list")
50 PRINT "Nodes in use:"; N
60 FOR I = 1 TO N
70 PRINT FNF$(I, "node"); " "; FNF$(I, "user"); " ("; FNF$(I, "activity"); ")"
80 NEXT I
