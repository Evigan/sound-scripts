@echo off
REM Converts all audio book or podcast narration MP3 files in the 
REM current directory into smaller mono companded files for easy listening.
REM Tests each file to see if stereo phase needs to be flipped.
REM Uses SOX.EXE from http://sox.sourceforge.net/
REM Uses FFMPEG.EXE from http://sourceforge.net/project/showfiles.php?group_id=205275&package_id=248632
REM Uses LAME.EXE from http://rarewares.org/mp3.html

REM -----------------------USER SETTINGS SECTION--------------------------------
REM Create a destination subfolder (name only, no spaces, no backslashes)
set SUB_FOLDER=small
REM Specify output bitrate (8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128)
set BIT_RATE=32
REM ----------------------------------------------------------------------------

REM First check to see that needed programs actually exist!
cmd.exe /c ffmpeg.exe > %temp%\temp.txt
type %temp%\temp.txt | find /i "ffmpeg" > nul
if errorlevel 1 goto FFMPEG
cls
cmd.exe /c sox.exe > %temp%\temp.txt
type %temp%\temp.txt | find /i "sox" > nul
if errorlevel 1 goto SOX
cls
cmd.exe /c lame.exe 2> %temp%\temp.txt
type %temp%\temp.txt | find /i /v "not recognized" | find /i "lame" > nul
if errorlevel 1 goto LAME
cls
del %temp%\temp.txt

REM Now check to see if we have any MP3 files
cd /d %1
if not exist *.mp3 goto MP3

REM Create the destination subfolder if it doesn't exist
if not exist %SUB_FOLDER%\nul mkdir %SUB_FOLDER%

REM Iterate through all the input MP3 files. If we haven't already done it, process each file.
for %%x in (*.mp3) do if not exist %SUB_FOLDER%/%%x call :PROC %%x
goto :EOF

:PROC
cls
REM Convert the input file to an uncompressed WAV file for processing by SOX
if exist %temp%\raw.wav del %temp%\raw.wav
ffmpeg -i %1 %temp%\raw.wav
if not exist %temp%\raw.wav goto ERROR

REM Combine the input channel stero channels into a single mono channel
cls
if exist %temp%\mono.wav del %temp%\mono.wav
echo Creating a simple MONO file...
sox %temp%\raw.wav -c 1 %temp%\mono.wav
if not exist %temp%\mono.wav goto ERROR

REM Use OOPS (out of phase stereo) to invert a channel before combining into identical stereo channels
if exist %temp%\oops.wav del %temp%\oops.wav
echo Creating an OOPS (out of phase stereo) file...
sox %temp%\raw.wav %temp%\oops.wav gain -6 oops 2> nul
REM If we can't make an OOPS file (like if input is already mono), it's recoverable. Just use the MONO file.
if not exist %temp%\oops.wav goto COMP
REM Now convert those identical OOPS channels into a single mono channel I'll call OOPM 
if exist %temp%\oopm.wav del %temp%\oopm.wav
echo Converting the OOPS file into a MONO file...
sox %temp%\oops.wav -c 1 %temp%\oopm.wav
if not exist %temp%\oopm.wav goto COMP

REM Delete some temporary files
del %temp%\raw.wav
del %temp%\oops.wav

REM Now a long and ugly comparison of whether the "mono" or "oopm" file has more audio
Echo Comparing the two files to see which has the best volume...

REM First, use SOX to get file stats and look for the line like "RMS     amplitude:     0.009554" 
sox %temp%\mono.wav -n stat 2> %temp%\temp.txt
type %temp%\temp.txt | find "RMS" | find "amplitude" > temp.bat
echo set mono=%%2>rms.bat
call temp.bat

REM Now we have to remove decimals and ignore leading zeros by using a fake "0x" hex identifier
set mono=%mono:.=0%
set mono=0x%mono%

REM Done with "mono", now follow the above procedure with the "oopm" file
sox %temp%\oopm.wav -n stat 2> %temp%\temp.txt
type %temp%\temp.txt | find "RMS" | find "amplitude" > temp.bat
echo set oopm=%%2>rms.bat
call temp.bat
set oopm=%oopm:.=0%
set oopm=0x%oopm%

REM Delete more temporary files
del temp.bat
del %temp%\temp.txt
del rms.bat

REM Here's where we do the actual compare: Subtract values and look for a minus sign.
set /a comp=%mono%-%oopm%
echo %comp% | find "-" > nul
if errorlevel 1 goto MONO
goto OOPM

REM In the end, there can be only one. The winner shall be named "mono.wav".
:MONO
Echo Looks like a simple MONO file works best.
del %temp%\oopm.wav
goto COMP
:OOPM
Echo Looks like a MONO file based on an OOPS file works best.
del %temp%\mono.wav
move %temp%\oopm.wav %temp%\mono.wav
goto COMP

REM Compand the audio to make it a consistent volume
:COMP
if exist %temp%\out.wav del %temp%\out.wav
Echo Companding the file to remove large volume differences...
sox %temp%\mono.wav %temp%\out.wav compand 0.3,5 6:-70,-60,-20 -10 -6 0.2 fade 1 2> nul
REM                                        |   | |  |   |   |   |   | |   |      |
REM                                        |   | |  |   |   |   |   | |   |      Ignore all error messages
REM                                        |   | |  |   |   |   |   | |   Fade-in for first second
REM                                        |   | |  |   |   |   |   | Initial sample time
REM                                        |   | |  |   |   |   |   Expected initial level
REM                                        |   | |  |   |   |   Overall output gain to avoid clipping
REM                                        |   | |  |   |   Output range from zero to this number
REM                                        |   | |  |   Input range from 0 to this number
REM                                        |   | |  Ignore companding below this level
REM                                        |   | Soft knee companding
REM                                        |   Decay time is long to prevent rising noise in pauses
REM                                        Attack time is fast to quiet loud music bumpers
del %temp%\mono.wav
if not exist %temp%\out.wav goto ERROR

REM Convert the processed WAV file into a smaller MP3 file
cls
lame -m m -b %BIT_RATE% %temp%\out.wav %temp%\out.mp3
del %temp%\out.wav
if not exist %temp%\out.mp3 goto ERROR

REM Put our new MP3 file in the destination folder
move /y %temp%\out.mp3 %SUB_FOLDER%\%1
if not exist %SUB_FOLDER%\%1 goto :ERROR
goto :EOF

:ERROR
echo An unexpected error occurred
pause
goto :EOF

:FFMPEG
if exist %temp%\temp.txt del %temp%\temp.txt
cls
echo You need to put FFMPEG.EXE :
echo http://sourceforge.net/project/showfiles.php?group_id=205275&package_id=248632
echo in your PATH (for example, in C:\Windows\System32)
pause
goto :EOF

:SOX
if exist %temp%\temp.txt del %temp%\temp.txt
cls
echo You need to put SOX.EXE:
echo http://sox.sourceforge.net/
echo in your PATH (for example, in C:\Windows\System32)
pause
goto :EOF

:LAME
if exist %temp%\temp.txt del %temp%\temp.txt
cls
echo You need to put LAME.EXE
echo http://rarewares.org/mp3.html
echo in your PATH (for example, in C:\Windows\System32)
pause
goto :EOF

:MP3
cls
echo You have to put this batch file in the same folder with a bunch of MP3 files.
pause
goto :EOF
