import logging
import os
from pathlib import Path

import uvicorn
from dotenv import load_dotenv
from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from starlette.exceptions import HTTPException

from .db import AppError
from .routes import NOT_FOUND, router
from .schemas import InputError

APP_DIR = Path(__file__).resolve().parent.parent
load_dotenv(APP_DIR / ".env", override=False)

logger = logging.getLogger(__name__)
INVALID_JSON = "Dữ liệu JSON không hợp lệ"
SERVER_ERROR = "Đã xảy ra lỗi máy chủ"

app = FastAPI(
    title="Ứng dụng BTL2",
    description="Quản lý biến thể sản phẩm, xem thống kê bán hàng, tính tổng thanh toán và tra điểm.",
)


@app.exception_handler(AppError)
async def handle_app_error(_request: Request, error: AppError):
    content = {"message": error.message}
    if error.code is not None:
        content["code"] = error.code
    return JSONResponse(content, status_code=error.status)


@app.exception_handler(InputError)
async def handle_input_error(_request: Request, error: InputError):
    return JSONResponse({"message": str(error)}, status_code=400)


@app.exception_handler(RequestValidationError)
async def handle_validation_error(_request: Request, error: RequestValidationError):
    first = error.errors()[0]
    kind = first["type"]
    field = first["loc"][-1]
    cause = first.get("ctx", {}).get("error")
    if kind == "json_invalid" or kind in ("model_attributes_type", "model_type"):
        message = INVALID_JSON
    elif isinstance(cause, InputError):
        message = str(cause)
    elif kind == "missing" and field in ("body", "maSanPham"):
        message = "Mã sản phẩm là bắt buộc"
    elif kind == "missing" and field == "maBienTheNoiBo":
        message = "Mã biến thể là bắt buộc"
    else:
        message = "Dữ liệu yêu cầu không hợp lệ"
    return JSONResponse({"message": message}, status_code=400)


@app.exception_handler(HTTPException)
async def handle_http_error(_request: Request, error: HTTPException):
    if error.status_code in (404, 405):
        return JSONResponse({"message": NOT_FOUND}, status_code=404)
    message = INVALID_JSON if error.status_code == 400 else "Không thể thực hiện yêu cầu"
    return JSONResponse({"message": message}, status_code=error.status_code, headers=error.headers)


@app.exception_handler(Exception)
async def handle_server_error(_request: Request, error: Exception):
    logger.error("Lỗi máy chủ (%s)", type(error).__name__)
    return JSONResponse({"message": SERVER_ERROR}, status_code=500)


app.include_router(router)
app.mount("/", StaticFiles(directory=APP_DIR / "public", html=True), name="public")


if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=int(os.getenv("APP_PORT") or "3000"))
