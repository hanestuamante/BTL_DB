import re
from datetime import date
from decimal import Decimal
from functools import partial
from typing import Annotated

from pydantic import BaseModel, BeforeValidator, Field, model_validator

from .procedures import SEARCH_SORTS

INT_MIN = -2147483648
INT_MAX = 2147483647
JS_WHITESPACE = " \t\n\r\v\f\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff"


class InputError(ValueError):
    pass


def empty(value):
    return value is None or (isinstance(value, str) and not value.strip(JS_WHITESPACE))


def integer(value, label, *, optional=False, minimum=INT_MIN):
    if empty(value):
        if optional:
            return None
        raise InputError(f"{label} là bắt buộc")
    if isinstance(value, str) and re.fullmatch(r"-?[0-9]+", value.strip(JS_WHITESPACE)):
        value = float(value)
    if type(value) in (int, float) and minimum <= value <= INT_MAX and value == int(value):
        return int(value)
    raise InputError(f"{label} phải là số nguyên trong khoảng {minimum} đến {INT_MAX}")


def string(value, label, maximum, *, optional=True):
    if empty(value):
        if optional:
            return None
        raise InputError(f"{label} là bắt buộc")
    if not isinstance(value, str):
        raise InputError(f"{label} phải là chuỗi ký tự")
    value = value.strip(JS_WHITESPACE)
    # JavaScript đếm độ dài chuỗi theo đơn vị UTF-16.
    if len(value.encode("utf-16-le", errors="surrogatepass")) // 2 > maximum:
        raise InputError(f"{label} không được vượt quá {maximum} ký tự")
    return value


def decimal(value, label, *, precision=14, nonnegative=False):
    if empty(value):
        return None
    if isinstance(value, str) and re.fullmatch(r"-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)", value.strip(JS_WHITESPACE)):
        value = float(value)
    limit = 10 ** (precision - 2)
    if type(value) in (int, float) and -limit < value < limit and (not nonnegative or value >= 0):
        return Decimal(str(value))
    constraint = "không âm và " if nonnegative else ""
    raise InputError(f"{label} phải là số tiền {constraint}trong phạm vi cho phép")


def parse_date(value, label):
    if empty(value):
        return None
    if isinstance(value, str) and re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", value):
        try:
            return date.fromisoformat(value)
        except ValueError:
            pass
    raise InputError(f"{label} phải là ngày hợp lệ theo định dạng YYYY-MM-DD")


def bit(value):
    if empty(value):
        return None
    if value in ("1", "true"):
        return True
    if value in ("0", "false"):
        return False
    raise InputError("Chỉ còn hàng phải là 0 hoặc 1")


def search_sort(value):
    if empty(value):
        return None
    if value in SEARCH_SORTS:
        return value
    raise InputError("Tiêu chí sắp xếp không hợp lệ")


def ordered(first, last, message):
    if first is not None and last is not None and first > last:
        raise InputError(message)


def variant_keys(ma_san_pham, ma_bien_the):
    return {
        "maSanPham": integer(ma_san_pham, "Mã sản phẩm"),
        "maBienTheNoiBo": string(ma_bien_the, "Mã biến thể", 30, optional=False),
    }


class ErrorResponse(BaseModel):
    message: str
    code: int | None = None


class VariantFields(BaseModel):
    mauSac: Annotated[str | None, BeforeValidator(partial(string, label="Màu sắc", maximum=60))] = None
    kichCo: Annotated[str | None, BeforeValidator(partial(string, label="Kích cỡ", maximum=30))] = None
    giaBanRieng: Annotated[
        Decimal | None, BeforeValidator(partial(decimal, label="Giá bán"), json_schema_input_type=float | str | None)
    ] = None
    tonKhoRieng: Annotated[
        int | None, BeforeValidator(
            partial(integer, label="Tồn kho", optional=True), json_schema_input_type=int | str | None
        )
    ] = None

    @model_validator(mode="before")
    @classmethod
    def array_without_fields(cls, value):
        return {} if isinstance(value, list) else value


class VariantKeys(BaseModel):
    maSanPham: Annotated[
        int, BeforeValidator(partial(integer, label="Mã sản phẩm"), json_schema_input_type=int | str)
    ]
    maBienTheNoiBo: Annotated[
        str, BeforeValidator(partial(string, label="Mã biến thể", maximum=30, optional=False))
    ]


class VariantCreate(VariantFields, VariantKeys):
    pass


class CatalogFilters(BaseModel):
    maDanhMuc: Annotated[
        int | None, BeforeValidator(partial(integer, label="Mã danh mục", optional=True, minimum=1))
    ] = None
    maThuongHieu: Annotated[
        int | None, BeforeValidator(partial(integer, label="Mã thương hiệu", optional=True, minimum=1))
    ] = None


class SearchFilters(CatalogFilters):
    tuKhoa: Annotated[str | None, BeforeValidator(partial(string, label="Từ khóa", maximum=100))] = None
    giaMin: Annotated[
        Decimal | None, BeforeValidator(partial(decimal, label="Giá tối thiểu", nonnegative=True))
    ] = None
    giaMax: Annotated[
        Decimal | None, BeforeValidator(partial(decimal, label="Giá tối đa", nonnegative=True))
    ] = None
    chiConHang: Annotated[bool | None, BeforeValidator(bit)] = None
    sapXep: Annotated[str | None, BeforeValidator(search_sort)] = None

    @model_validator(mode="after")
    def check_price_range(self):
        ordered(self.giaMin, self.giaMax, "Giá tối thiểu phải nhỏ hơn hoặc bằng giá tối đa")
        return self


class ReportFilters(CatalogFilters):
    tuNgay: Annotated[date | None, BeforeValidator(partial(parse_date, label="Ngày bắt đầu"))] = None
    denNgay: Annotated[date | None, BeforeValidator(partial(parse_date, label="Ngày kết thúc"))] = None
    soLuongToiThieu: Annotated[
        int | None, BeforeValidator(partial(integer, label="Số lượng bán tối thiểu", optional=True, minimum=0))
    ] = None
    doanhThuToiThieu: Annotated[
        Decimal | None, BeforeValidator(partial(decimal, label="Doanh thu tối thiểu", precision=18, nonnegative=True))
    ] = None

    @model_validator(mode="after")
    def check_date_range(self):
        ordered(self.tuNgay, self.denNgay, "Ngày bắt đầu phải nhỏ hơn hoặc bằng ngày kết thúc")
        return self


def whole(label, **options):
    return BeforeValidator(partial(integer, label=label, **options), json_schema_input_type=int | str)


class OrderItem(VariantKeys):
    soLuong: Annotated[int, whole("Số lượng")]


class OrderCreate(BaseModel):
    maDiaChi: Annotated[int | None, whole("Địa chỉ", optional=True)] = None
    maPhuongThucVC: Annotated[int | None, whole("Phương thức vận chuyển", optional=True)] = None
    maPhuongThucTT: Annotated[int | None, whole("Phương thức thanh toán", optional=True)] = None
    matHang: list[OrderItem] = []
    maVoucher: Annotated[str | None, BeforeValidator(partial(string, label="Mã voucher", maximum=20))] = None
    diemSuDung: Annotated[int | None, whole("Số điểm sử dụng", optional=True)] = None
    loiNhan: Annotated[str | None, BeforeValidator(partial(string, label="Lời nhắn", maximum=500))] = None


class StatusChange(BaseModel):
    trangThaiMoi: Annotated[str | None, BeforeValidator(partial(string, label="Trạng thái mới", maximum=20))] = None
    # Để trống: hệ thống thực hiện (xác nhận thanh toán trực tuyến).
    maNhanVien: Annotated[str | None, BeforeValidator(partial(string, label="Mã nhân viên", maximum=10))] = None


def stars(value):
    value = integer(value, "Số sao", minimum=1)
    if value > 5:
        raise InputError("Số sao phải từ 1 đến 5")
    return value


class ReviewCreate(BaseModel):
    soThuTuDong: Annotated[int, whole("Mặt hàng")]
    soSao: Annotated[int, BeforeValidator(stars, json_schema_input_type=int | str)] = Field(None, validate_default=True)
    binhLuan: Annotated[str | None, BeforeValidator(partial(string, label="Nhận xét", maximum=2000))] = None
    dungMoTa: Annotated[str | None, BeforeValidator(partial(string, label="Đúng mô tả", maximum=100))] = None
