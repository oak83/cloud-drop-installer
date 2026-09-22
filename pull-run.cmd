@echo off
rem Одна команда для cmd.exe: скачать и запустить.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pull-run.ps1" %*
