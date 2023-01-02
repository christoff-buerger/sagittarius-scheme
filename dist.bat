@echo off

rem Modify this to your installed directory

set SASH="%ProgramFiles%\Sagittarius\sash.exe"

rem This is one hell ugly workaround for appveyor
rem for some reason, on the server Sagittarius 
rem causes C5000005 (ACCESS VIOLATION), very
rem frequently. The funny thins is that it might
rem complete the task. So we retry number of times
rem until it gets somewhere
set RETRY=0
set MAX_RETRY=100

goto :entry

:invoke
set RETRY=0
set COMMAND=%1
shift
:retry
%SASH% %COMMAND% %*
if %errorlevel% neq 0 (
    set /a RETRY=%RETRY%+1
    if %RETRY% neq %MAX_RETRY% goto retry
)
rem return to caller
goto:eof

rem insn
:insn
echo "Generating instructions files"
cd src
call :invoke geninsn %1
cd ..
goto:eof

rem precomp
:precomp
echo "Generating compiled library files"
cd src
call :invoke genlib %1
cd ..
call :insn dummy %1
cd tools\scripts
echo "Generating builtin keywords"
call :invoke builtin-keywords.scm
echo "Generating builtin symbols"
call :invoke builtin-symbols.scm
cd  ..
goto:eof

rem stub
:stub
echo "Generating library from stub"
cd src
call :invoke genstub %1
cd ..
goto:eof

rem srfi
:srfi
echo Generating R7RS style SRFI libraries
call :invoke -L./sitelib ./tools/scripts/r7rs-srfi-gen.scm -p ./ext -p ./sitelib/srfi %1
goto:eof

rem tzdata
:tz
echo "Generating TZ database"
call :invoke ./tools/scripts/compile-tzdatabase.scm -o ext/time/sagittarius/tzdata.scm -w ext/time/sagittarius/win-mappings.scm -l ext/time/sagittarius/leap-table.scm -r %1
goto:eof

rem unicode
:unicode
echo "Generating Unicode codepoints"
call :invoke ./tools/scripts/compile-unicode.scm %1
goto:eof

rem html
:html
echo "Generating HTML entities"
call :invoke ./tools/scripts/html-entities.scm -o sitelib/text/xml/entities-list.scm %1
goto:eof

rem gen
:gen
call :stub
call :precomp
call :srfi
call :tz
call :unicode
call :html
goto:eof

rem clean
:clean
call :stub "-c"
call :precomp "-c"
call :srfi "-c"
call :tz "-c"
call :unicode "-c"
call :html "-c"
goto:eof

rem entry point
:entry
if not exist "%SASH%" goto err
if "%1"=="" goto usage
for %%x in (%*) do call :%%x
goto end

:usage
echo "usage: %0 precomp|stub|srfi|tz|clean"
echo "    gen:        generates all files"
echo "    precomp:    generates precompiled files"
echo "    stub:       generates stub files"
echo "    srfi:       generates R7RS style SRFI libraries"
echo "    tz:         generates TZ database"
echo "    unicode:    generates Unicode codepoints"
echo "    html:       generates HTML entries"
echo "    clean:      cleasn generated files"

goto :end

:err
echo "Sagittarius is not installed. Default %SASH%"

:end

exit /b 0
