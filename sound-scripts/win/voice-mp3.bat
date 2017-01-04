@ECHO off

:: Most ideas taken from:
:: https://habrahabr.ru/post/118454/
:: http://stackoverflow.com/questions/2968417/compressing-voice-with-mp3

SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

SET me=%~n0
SET parent=%~dp0

SET BIN=%~dp0bin

:: SoX - Sound eXchange. The Swiss Army knife of sound processing. http://sox.sourceforge.net/
SET SOX=%BIN%\sox.exe
:: High quality MPEG Audio Layer III (MP3) encoder. http://lame.sourceforge.net/
SET LAME=%BIN%\lame.exe

:: Which means 'Speech'
SET ID3_TAG="101"
:: Album art image
SET ID3_IMAGE="%parent%AroundChrist-300x300.png"
:: Album name
SET ID3_ALBUM="Church 'Around Christ'"

ECHO.
IF [%1]==[] ECHO "USAGE: %me% WAV_FOLDER" && GOTO end

SET WAV_FOLDER=%1

:: taken from http://sox.sourceforge.net/Docs/Scripts
 :: compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 ^
 :: compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 ^
 :: compand 1,4 6:-80,-80,-75,-25,0,0 -5 -30 1 ^
 :: read more about 'compand' - http://sox.sourceforge.net/sox.html
 ::      "%LAME%"" -V 9 --vbr-new -mm -h -q 0 ^

FOR %%A in (%WAV_FOLDER%\*.WAV) DO (

  SET SOX_RESULT=%%~dpA%%~nA-clean%%~xA

  ECHO.
  ECHO    %me% ^>^>^> Doing SoX magic with voice-cleanup of %%A
  ECHO    %me% ^>^>^> Resulting file ---^> !SOX_RESULT!
          ECHO.
        ECHO    %me% ^>^>^> Doing MP3 compression ---^> "%%~nA.mp3"

  "%SOX%" "%%A" -t wav - ^
        --show-progress ^$
        remix - ^
        highpass 100 ^
        norm ^
        compand 0.3,1 6:-70,-60,-20 -5 -90 0.2 ^
        vad -T 0.6 -p 0.2 -t 5 ^
        fade 0.1 ^
        reverse ^
        vad -T 0.6 -p 0.2 -t 5 ^
        fade 0.1 ^
        reverse ^
        norm -0.5 ^
        rate -v 22050 | ^
  "%LAME%" -V 8 --vbr-new -h -q 0 ^
        --ti %ID3_IMAGE% ^
        --tl %ID3_ALBUM% ^
        --tg %ID3_TAG% ^
        - ^
        "%%~dpnA.mp3"

        IF %ERRORLEVEL% NEQ 0 GOTO:end
        ECHO.
        ECHO    %me% ^>^>^> MP3 compression to "%%~nA.mp3" completed
)

:end
EXIT /B %ERRORLEVEL%