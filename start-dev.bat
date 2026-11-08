@echo off
setlocal
chcp 936 >nul
title DevFlow AI - 一键启动

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"

echo ============================================================
echo   DevFlow AI 本地启动
echo   后端 http://127.0.0.1:8000    前端 http://127.0.0.1:3000
echo ============================================================
echo.

if not exist "%BACKEND%\.venv\Scripts\python.exe" (
    echo [错误] 未找到 backend\.venv，请先创建虚拟环境并安装 requirements.txt
    echo.
    pause
    exit /b 1
)
if not exist "%FRONTEND%\node_modules" (
    echo [错误] 未找到 frontend\node_modules，请先在 frontend 目录执行 npm install
    echo.
    pause
    exit /b 1
)

rem ---- 依赖服务连通性检查（仅提示，不自动启动 Docker） ----
set "DEPS_OK=1"
netstat -ano | findstr /R /C:":5432 .*LISTENING" >nul 2>&1
if errorlevel 1 (
    echo [警告] PostgreSQL 5432 未监听，后端可能启动失败
    set "DEPS_OK=0"
)
netstat -ano | findstr /R /C:":19530 .*LISTENING" >nul 2>&1
if errorlevel 1 (
    echo [警告] Milvus 19530 未监听，向量检索将不可用
    set "DEPS_OK=0"
)
if "%DEPS_OK%"=="0" (
    echo [提示] 请先确认 Docker Desktop 已启动，并执行: docker compose up -d postgres etcd minio milvus
    echo.
)

rem ---- 端口占用检查 ----
netstat -ano | findstr /R /C:":8000 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [警告] 端口 8000 已被占用，后端窗口可能会报错
    echo.
)
netstat -ano | findstr /R /C:":3000 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo [警告] 端口 3000 已被占用，前端可能自动切换端口
    echo.
)

rem ---- 嵌入模型走本地缓存，避免每次联网校验 ----
set "HF_ENDPOINT=https://hf-mirror.com"
set "HF_HUB_OFFLINE=1"

echo [1/2] 启动后端 (FastAPI :8000) ...
start "DevFlow-API-8000" /D "%BACKEND%" cmd /k ".venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000"

echo [2/2] 启动前端 (Next.js :3000) ...
start "DevFlow-Web-3000" /D "%FRONTEND%" cmd /k "npm run dev -- -p 3000"

echo.
echo 已发出启动指令，两个独立窗口已打开：
echo    - DevFlow-API-8000  后端，看到 Application startup complete 即就绪
echo    - DevFlow-Web-3000  前端，看到 Ready 后访问 http://127.0.0.1:3000
echo.
echo 关闭方式：在各自窗口按 Ctrl+C，或直接关闭窗口
echo.
timeout /t 5 >nul
exit /b 0
