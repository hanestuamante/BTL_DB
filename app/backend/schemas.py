from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, model_validator


class Form(BaseModel):
    """Dữ liệu gửi từ form. Ô để trống thành NULL; kiểm tra nghiệp vụ do CSDL làm."""

    model_config = ConfigDict(str_strip_whitespace=True)

    @model_validator(mode="before")
    @classmethod
    def blank_to_null(cls, data):
        if isinstance(data, dict):
            return {key: None if value == "" else value for key, value in data.items()}
        return data


# Tên trường trùng tên tham số của thủ tục (xem PROCEDURES trong procedures.py).
class VariantFields(Form):
    MauSac: str | None = None
    KichCo: str | None = None
    GiaBanRieng: Decimal | None = None
    TonKhoRieng: int | None = None


class VariantCreate(VariantFields):
    MaSanPham: int | None = None
    MaBienTheNoiBo: str | None = None


class SearchFilters(Form):
    TuKhoa: str | None = None
    MaDanhMuc: int | None = None
    MaThuongHieu: int | None = None
    GiaMin: Decimal | None = None
    GiaMax: Decimal | None = None
    ChiConHang: bool | None = None
    SapXep: str | None = None


class ReportFilters(Form):
    MaDanhMuc: int | None = None
    MaThuongHieu: int | None = None
    TuNgay: date | None = None
    DenNgay: date | None = None
    SoLuongToiThieu: int | None = None
    DoanhThuToiThieu: Decimal | None = None


class OrderItem(Form):
    maSanPham: int
    maBienTheNoiBo: str
    soLuong: int


class OrderCreate(Form):
    maDiaChi: int | None = None
    maPhuongThucVC: int | None = None
    maPhuongThucTT: int | None = None
    matHang: list[OrderItem] = []
    maVoucher: str | None = None
    diemSuDung: int | None = None
    loiNhan: str | None = None


class StatusChange(Form):
    trangThaiMoi: str | None = None
    maNhanVien: str | None = None  # để trống: hệ thống thực hiện


class ReviewCreate(Form):
    soThuTuDong: int
    soSao: int | None = None
    binhLuan: str | None = None
    dungMoTa: str | None = None
