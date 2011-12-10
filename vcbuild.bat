
set NODE_PATH=%NODE_PATH%;c:\dev2\node-mapnik\lib;
set NODE_PATH=%NODE_PATH%;c:\dev2\node-zipfile\lib;
set NODE_PATH=%NODE_PATH%;c:\dev2\node-srs\lib;
set NODE_PATH=%NODE_PATH%;c:\dev2\node-sqlite3\lib;
set NODE_PATH=%NODE_PATH%;c:\dev2\contextify\lib;

set PATH=%PATH%;c:\\Python27\;c:\\mapnik-2.0\lib;c:\msysgit\msysgit\bin;c:\msysgit\msysgit\mingw\bin;c:\cygwin\bin;C:\Program Files (x86)\GnuWin32\bin
set PATH=%PATH%;c:\\dev2\node-zipfile\\lib
set PATH=c:\\node\\Release;%PATH%

rem for npm.cmd
rem set PATH=c:\dev2;%PATH%

rem --no-rollback
rem npm install --verbose --force --no-rollback 
rem --force
node index.js