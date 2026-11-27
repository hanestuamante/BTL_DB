from typing import Annotated

from fastapi import APIRouter, Depends, Query

from . import procedures
from .db import AppError
from .schemas import OrderCreate, ReportFilters, ReviewCreate, SearchFilters, StatusChange, VariantCreate, VariantFields

router = APIRouter(prefix="/api")


@router.get("/health")
def health():
    procedures.ping()
    return {"status": "ok"}


@router.get("/lookup/{name}")
def lookup(name: str):
    if name not in procedures.LOOKUP_QUERIES:
        raise AppError(404, "Không tìm thấy danh sách")
    return procedures.lookup(name)


# ---- Biến thể: tìm kiếm và CRUD qua thủ tục ----
@router.get("/bien-the")
def search_variants(filters: Annotated[SearchFilters, Query()]):
    return procedures.run_procedure("search", filters.model_dump())


def variant_message(operation, values):
    # Thủ tục trả về một dòng có cột ThongBao, ví dụ "Thêm biến thể thành công."
    return {"message": procedures.run_procedure(operation, values)[0]["ThongBao"]}


@router.post("/bien-the", status_code=201)
def create_variant(body: VariantCreate):
    return variant_message("create", body.model_dump())


@router.put("/bien-the/{maSanPham}/{maBienThe}")
def update_variant(maSanPham: int, maBienThe: str, body: VariantFields):
    keys = {"MaSanPham": maSanPham, "MaBienTheNoiBo": maBienThe}
    return variant_message("update", {**keys, **body.model_dump()})


@router.delete("/bien-the/{maSanPham}/{maBienThe}")
def delete_variant(maSanPham: int, maBienThe: str):
    return variant_message("remove", {"MaSanPham": maSanPham, "MaBienTheNoiBo": maBienThe})


# ---- Thống kê ----
@router.get("/thong-ke")
def sales_report(filters: Annotated[ReportFilters, Query()]):
    return procedures.run_procedure("report", filters.model_dump())


# ---- Quản trị đơn hàng ----
@router.get("/quan-ly-don")
def manage_orders():
    return procedures.manage_orders()


@router.get("/quan-ly-don/{ma}")
def order_detail(ma: int):
    detail = procedures.order_detail(ma)
    if detail is None:
        raise AppError(404, "Không tìm thấy đơn hàng.")
    return detail


@router.put("/quan-ly-don/{ma}/trang-thai")
def change_order_status(ma: int, body: StatusChange):
    return procedures.change_order_status(ma, body.trangThaiMoi, body.maNhanVien)


# ---- Khách hàng Nguyễn Văn An: đặt hàng và đơn của tôi ----
@router.get("/dat-hang")
def order_form():
    return procedures.order_form()


@router.post("/dat-hang/tam-tinh")
def preview_order(body: OrderCreate):
    rows = procedures.preview_order(body.model_dump())
    if not rows:
        raise AppError(400, "Không có chính sách điểm đang hiệu lực.")
    return rows[0]


@router.post("/dat-hang", status_code=201)
def create_order(body: OrderCreate):
    return procedures.create_order(body.model_dump())


@router.get("/don-cua-toi")
def my_orders():
    return procedures.my_orders()


def my_order_id(ma: int):
    if not procedures.is_my_order(ma):
        raise AppError(404, "Không tìm thấy đơn hàng của bạn.")
    return ma


MyOrder = Annotated[int, Depends(my_order_id)]


@router.get("/don-cua-toi/{ma}")
def my_order_detail(order_id: MyOrder):
    return procedures.order_detail(order_id)


@router.post("/don-cua-toi/{ma}/danh-gia", status_code=201)
def add_review(order_id: MyOrder, body: ReviewCreate):
    procedures.add_review(order_id, body.model_dump())
    return {"message": "Đã gửi đánh giá"}


@router.put("/don-cua-toi/{ma}/huy")
def cancel_my_order(order_id: MyOrder):
    return procedures.cancel_my_order(order_id)


@router.put("/don-cua-toi/{ma}/nhan-hang")
def receive_my_order(order_id: MyOrder):
    return procedures.receive_my_order(order_id)


# ---- Tra điểm khả dụng ----
@router.get("/khach-hang")
def list_customers():
    return procedures.list_customers()


@router.get("/khach-hang/{ma}/diem")
def customer_points(ma: int):
    return {"maKhachHang": ma, "diemKhaDung": procedures.customer_points(ma)}
