import logging
import os

import pymssql

logger = logging.getLogger(__name__)
# Mã lỗi khi không kết nối được: 18456 sai đăng nhập, 200xx lỗi mạng / server tắt (FreeTDS).
CONNECTION_CODES = {18456, 20002, 20003, 20004, 20006, 20009}


class AppError(Exception):
    def __init__(self, status, message, code=None):
        super().__init__(message)
        self.status = status
        self.message = message
        self.code = code


def database_error(error, procedure):
    """Đổi lỗi pymssql thành AppError để hiện lên web."""
    args = error.args[0] if error.args and isinstance(error.args[0], tuple) else error.args
    code = args[0] if args and isinstance(args[0], int) else None
    if code is not None and 50000 <= code <= 50999:
        # Lỗi nhóm tự THROW trong thủ tục / trigger: hiện nguyên văn.
        message = args[1].decode("utf-8", "replace") if isinstance(args[1], bytes) else str(args[1])
        message = message.partition("DB-Lib error message")[0].strip()
        return AppError(400, message or f"CSDL từ chối dữ liệu (mã lỗi {code}).", code)
    if code == 547:
        return AppError(400, "Dữ liệu vi phạm ràng buộc tham chiếu hoặc điều kiện của CSDL.", code)
    if code in (2627, 2601):
        return AppError(400, "Dữ liệu bị trùng khóa hoặc giá trị phải duy nhất.", code)
    if code == 2812:
        return AppError(503, f"Chưa có thủ tục {procedure} trong CSDL.", code)
    if code is None or code in CONNECTION_CODES:
        return AppError(503, "Không thể kết nối CSDL.", code)
    logger.error("Lỗi CSDL mã %s: %s", code, args)
    return AppError(500, f"Lỗi CSDL (mã {code}).", code)


def query(statement, params=(), *, procedure=None):
    """Chạy một câu SQL, trả về các dòng của bảng kết quả đầu tiên."""
    server = os.getenv("DB_SERVER") or "localhost"
    try:
        with pymssql.connect(
            server="127.0.0.1" if server == "localhost" else server,  # Docker chỉ mở IPv4
            port=os.getenv("DB_PORT") or "1433",
            database=os.getenv("DB_NAME") or "BTL2",
            user=os.getenv("DB_USER") or "sa",
            password=os.getenv("DB_PASSWORD", ""),
            charset="UTF-8",
            autocommit=True,  # thủ tục tự quản lý giao dịch
            login_timeout=5,
            timeout=30,
        ) as connection:
            cursor = connection.cursor(as_dict=True)
            cursor.execute(statement, params)
            # Bỏ qua các thông báo "x rows affected" để tới bảng kết quả.
            while cursor.description is None:
                if not cursor.nextset():
                    return []
            return cursor.fetchall()
    except pymssql.Error as error:
        raise database_error(error, procedure) from None
