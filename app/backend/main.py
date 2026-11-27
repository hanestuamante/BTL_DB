import os
from pathlib import Path

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from .db import AppError
from .routes import router

APP_DIR = Path(__file__).resolve().parent.parent
load_dotenv(APP_DIR / ".env", override=False)

app = FastAPI(title="Ứng dụng BTL2")


# Mọi lỗi trả về dạng {"message": ...} để web hiện bằng toast.
@app.exception_handler(AppError)
async def handle_app_error(_request, error: AppError):
    return JSONResponse({"message": error.message, "code": error.code}, status_code=error.status)


@app.exception_handler(RequestValidationError)
async def handle_validation_error(_request, error: RequestValidationError):
    field = error.errors()[0]["loc"][-1]
    return JSONResponse({"message": f"Giá trị không hợp lệ: {field}"}, status_code=400)


app.include_router(router)
app.mount("/", StaticFiles(directory=APP_DIR / "public", html=True), name="public")  # trang HTML/CSS/JS

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=int(os.getenv("APP_PORT") or "3000"))
