from typing import Annotated

from fastapi import APIRouter, Depends, Query

from . import procedures
from .db import AppError
from .schemas import ErrorResponse, OrderCreate, ReportFilters, ReviewCreate, SearchFilters, StatusChange, VariantCreate, VariantFields, integer, variant_keys

NOT_FOUND = "Không tìm thấy đường dẫn"


router = APIRouter(
    prefix="/api",
    responses={
        "4XX": {"model": ErrorResponse, "description": "Yêu cầu không hợp lệ (400) hoặc không tìm thấy (404)."},
        503: {"model": ErrorResponse, "description": "CSDL không khả dụng."},
    },
)


@router.get("/health", tags=["CSDL"], summary="Kiểm tra kết nối CSDL")
def health():
    procedures.ping()
    return {"status": "ok"}


@router.get(
    "/lookup/{name}",
    tags=["Danh mục tra cứu"],
    summary="Lấy danh sách cho ô chọn",
    description="Chọn danh-muc, thuong-hieu hoặc san-pham.",
)
def lookup(name: str):
    if name not in procedures.LOOKUP_QUERIES:
        raise AppError(404, NOT_FOUND)
    return procedures.lookup(name)


@router.get("/bien-the", tags=["Biến thể"], summary="Tìm và lọc biến thể sản phẩm")
def search_variants(filters: Annotated[SearchFilters, Query()]):
    return procedures.run_procedure("search", filters.model_dump())


@router.post("/bien-the", status_code=201, tags=["Biến thể"], summary="Thêm biến thể sản phẩm")
def create_variant(body: VariantCreate):
    row = procedures.run_procedure("create", body.model_dump())[0]
    return {
        "maSanPham": row["MaSanPham"],
        "maBienTheNoiBo": row["MaBienTheNoiBo"],
        "message": row["ThongBao"],
    }


def path_variant_keys(maSanPham: str, maBienThe: str):
    return variant_keys(maSanPham, maBienThe)


@router.put("/bien-the/{maSanPham}/{maBienThe}", tags=["Biến thể"], summary="Sửa biến thể theo khóa ghép")
def update_variant(keys: Annotated[dict, Depends(path_variant_keys)], body: VariantFields | None = None):
    fields = (body or VariantFields()).model_dump()
    row = procedures.run_procedure("update", {**keys, **fields})[0]
    return {**keys, "message": row["ThongBao"]}


@router.delete("/bien-the/{maSanPham}/{maBienThe}", tags=["Biến thể"], summary="Xóa biến thể theo khóa ghép")
def delete_variant(keys: Annotated[dict, Depends(path_variant_keys)]):
    row = procedures.run_procedure("remove", keys)[0]
    return {**keys, "message": row["ThongBao"]}


@router.get("/thong-ke", tags=["Thống kê"], summary="Thống kê sản phẩm trong các đơn đã giao")
def sales_report(filters: Annotated[ReportFilters, Query()]):
    rows = procedures.run_procedure("report", filters.model_dump())
    # Giữ BIGINT dạng chuỗi để trình duyệt sắp xếp được cả số lớn.
    for row in rows:
        if row.get("TongSoLuongBan") is not None:
            row["TongSoLuongBan"] = str(row["TongSoLuongBan"])
    return rows


@router.get("/don-hang", tags=["Đơn hàng"], summary="Lấy danh sách đơn hàng")
def list_orders():
    return procedures.list_orders()


@router.get(
    "/don-hang/{ma}/tong-thanh-toan",
    tags=["Đơn hàng"],
    summary="Tính tổng thanh toán và lấy các khoản cấu thành",
)
def order_total(ma: str):
    order_id = integer(ma, "Mã đơn hàng")
    result = procedures.order_total(order_id)
    total = result["tongThanhToan"]
    if total == -1:
        raise AppError(400, "Mã đơn hàng phải là số nguyên dương.", -1)
    if total == -2:
        raise AppError(404, "Không tìm thấy đơn hàng.", -2)
    if total == -3:
        raise AppError(400, "Đơn hàng chưa có chi tiết.", -3)
    return {"maDonHang": order_id, **result}


@router.get("/quan-ly-don", tags=["Đơn hàng"], summary="Danh sách đơn hàng và nhân viên xử lý")
def manage_orders():
    return procedures.manage_orders()


@router.get("/quan-ly-don/{ma}", tags=["Đơn hàng"], summary="Chi tiết đơn: mặt hàng, voucher và cách tính tiền")
def order_detail(ma: str):
    detail = procedures.order_detail(integer(ma, "Mã đơn hàng"))
    if detail is None:
        raise AppError(404, "Không tìm thấy đơn hàng.")
    return detail


@router.put("/quan-ly-don/{ma}/trang-thai", tags=["Đơn hàng"], summary="Chuyển trạng thái bằng sp_CapNhatTrangThaiDon")
def change_order_status(ma: str, body: StatusChange):
    return procedures.change_order_status(integer(ma, "Mã đơn hàng"), body.trangThaiMoi, body.maNhanVien)


@router.get("/don-cua-toi", tags=["Đặt hàng"], summary="Đơn hàng của Nguyễn Văn An")
def my_orders():
    return procedures.my_orders()


def my_order_id(ma: str):
    order_id = integer(ma, "Mã đơn hàng")
    if not procedures.is_my_order(order_id):
        raise AppError(404, "Không tìm thấy đơn hàng của bạn.")
    return order_id


@router.get("/don-cua-toi/{ma}", tags=["Đặt hàng"], summary="Chi tiết một đơn của khách")
def my_order_detail(order_id: Annotated[int, Depends(my_order_id)]):
    return procedures.order_detail(order_id)


@router.post("/don-cua-toi/{ma}/danh-gia", status_code=201, tags=["Đặt hàng"], summary="Khách đánh giá một món đã giao")
def add_review(order_id: Annotated[int, Depends(my_order_id)], body: ReviewCreate):
    try:
        procedures.add_review(order_id, body.model_dump())
    except AppError as error:
        if error.code == 2627:
            raise AppError(400, "Món này đã được đánh giá rồi.", 2627) from None
        raise
    return {"message": "Đã gửi đánh giá"}


@router.put("/don-cua-toi/{ma}/huy", tags=["Đặt hàng"], summary="Khách hủy đơn của mình")
def cancel_my_order(order_id: Annotated[int, Depends(my_order_id)]):
    return procedures.cancel_my_order(order_id)


@router.put("/don-cua-toi/{ma}/nhan-hang", tags=["Đặt hàng"], summary="Khách xác nhận đã nhận hàng")
def receive_my_order(order_id: Annotated[int, Depends(my_order_id)]):
    return procedures.receive_my_order(order_id)


@router.get("/dat-hang", tags=["Đặt hàng"], summary="Dữ liệu cho trang đặt hàng của Nguyễn Văn An")
def order_form():
    return procedures.order_form()


@router.post("/dat-hang/tam-tinh", tags=["Đặt hàng"], summary="Tạm tính tiền trước khi đặt, không ghi dữ liệu")
def preview_order(body: OrderCreate):
    rows = procedures.preview_order(body.model_dump())
    if not rows:
        raise AppError(400, "Không có chính sách điểm đang hiệu lực.")
    return rows[0]


@router.post("/dat-hang", status_code=201, tags=["Đặt hàng"], summary="Đặt hàng bằng sp_TaoDonHang")
def create_order(body: OrderCreate):
    return procedures.create_order(body.model_dump())


@router.get("/khach-hang", tags=["Khách hàng"], summary="Lấy danh sách khách hàng")
def list_customers():
    return procedures.list_customers()


@router.get("/khach-hang/{ma}/diem", tags=["Khách hàng"], summary="Tra điểm khả dụng")
def customer_points(ma: str):
    customer_id = integer(ma, "Mã khách hàng")
    points = procedures.customer_points(customer_id)
    if points == -1:
        raise AppError(400, "Mã khách hàng phải là số nguyên dương.", -1)
    if points == -2:
        raise AppError(404, "Không tìm thấy khách hàng.", -2)
    return {"maKhachHang": customer_id, "diemKhaDung": points}
