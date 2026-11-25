import logging
import os

import pymssql

logger = logging.getLogger(__name__)
CONNECTION_CODES = {0, 18456, 20002, 20003, 20004, 20006, 20009}


class AppError(Exception):
    def __init__(self, status, message, code=None):
        super().__init__(message)
        self.status = status
        self.message = message
        self.code = code


def database_error(error, procedure):
    args = error.args
    if args and isinstance(args[0], tuple):  # lỗi kết nối: pymssql bọc thêm một lớp tuple
        args = args[0]
    code = args[0] if args and isinstance(args[0], int) else None
    if code is not None and 50000 <= code <= 50999:
        message = args[1] if len(args) > 1 else ""
        if isinstance(message, bytes):
            message = message.decode("utf-8", errors="replace")
        message = (message or "").partition("DB-Lib error message")[0].strip()
        return AppError(400, message or f"CSDL từ chối dữ liệu (mã lỗi {code}).", code)
    if code == 547:
        return AppError(400, "Dữ liệu vi phạm ràng buộc tham chiếu hoặc điều kiện của CSDL.", code)
    if code in (2627, 2601):
        return AppError(400, "Dữ liệu bị trùng khóa hoặc giá trị phải duy nhất.", code)
    if code == 2812:
        message = f"Chưa có procedure {procedure} trong CSDL" if procedure else "Chưa có procedure trong CSDL"
        return AppError(503, message, code)
    if code in CONNECTION_CODES or isinstance(error, pymssql.InterfaceError):
        return AppError(503, "Không thể kết nối hoặc nhận phản hồi từ CSDL.", code)
    logger.error("Lỗi CSDL (%s, mã %s)", type(error).__name__, code)
    return AppError(500, "Đã xảy ra lỗi máy chủ")


def query(statement, params=(), *, procedure=None):
    connection = None
    server = os.getenv("DB_SERVER") or "localhost"
    try:
        connection = pymssql.connect(
            server="127.0.0.1" if server == "localhost" else server,
            port=os.getenv("DB_PORT") or "1433",
            database=os.getenv("DB_NAME") or "BTL2",
            user=os.getenv("DB_USER") or "sa",
            password=os.getenv("DB_PASSWORD", ""),
            charset="UTF-8",
            autocommit=True,
            login_timeout=5,
            timeout=30,
        )
        cursor = connection.cursor(as_dict=True)
        cursor.execute(statement, params)
        # Bỏ qua kết quả đếm dòng để lấy tập kết quả đầu tiên.
        while cursor.description is None:
            if not cursor.nextset():
                return []
        return cursor.fetchall()
    except pymssql.Error as error:
        raise database_error(error, procedure) from None
    finally:
        if connection is not None:
            try:
                connection.close()
            except pymssql.Error as error:
                logger.error("Không thể đóng kết nối CSDL (%s)", type(error).__name__)
