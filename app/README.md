# Ứng dụng BTL2

Ứng dụng quản lý biến thể, xem thống kê bán hàng, tính tổng thanh toán và tra điểm khả dụng. Backend dùng Python 3.12, FastAPI và SQL Server 2022 với CSDL `BTL2`.

## Chạy ứng dụng

1. Nạp các script theo thứ tự trong [README của repo](../README.md#thứ-tự-chạy-script-sql). Nếu chưa có Q1, chạy thêm `../../dev/stub_sp_tim_bien_the.sql` trong CSDL `BTL2`. Stub nằm ngoài repo và chỉ tạo procedure khi chưa có. Dùng script chính thức của Khanh khi hoàn tất T28.
2. Nếu chưa có `app/.env`, tạo tệp này từ `app/.env.example` và điền cấu hình kết nối SQL Server. Biến môi trường đã đặt trước khi chạy được ưu tiên.
3. Từ thư mục gốc của repo, chạy các lệnh tương ứng với hệ điều hành.

**macOS**

```sh
cd app
python3.12 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m backend.main
```

**Windows (PowerShell)**

```powershell
cd app
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe -m backend.main
```

Mở `http://127.0.0.1:3000` hoặc cổng đã đặt trong `APP_PORT`. Mở `/docs` để xem và thử API. `GET /api/health` kiểm tra kết nối CSDL.

Nếu đã kích hoạt môi trường ảo, có thể chạy trực tiếp `uvicorn backend.main:app --host 127.0.0.1 --port 3000` trong thư mục `app`. Với lệnh này, đổi `--port` khi cần dùng cổng khác.

## Hợp đồng Q1 cho Khanh

Backend gọi `dbo.sp_TimBienThe` với các tham số có tên bên dưới. Bộ lọc bỏ trống được truyền bằng `NULL`.

| Tham số | Kiểu | Ý nghĩa |
|---|---|---|
| `@TuKhoa` | `NVARCHAR(100)` | Tìm theo tên sản phẩm hoặc mã biến thể |
| `@MaDanhMuc` | `INT` | Mã danh mục, gồm các danh mục con |
| `@MaThuongHieu` | `INT` | Mã thương hiệu |
| `@GiaMin`, `@GiaMax` | `DECIMAL(14,2)` | Khoảng giá bán, gồm hai đầu mút |
| `@ChiConHang` | `BIT` | `1` chỉ lấy tồn kho lớn hơn 0. `0` và `NULL` lấy mọi mức tồn kho |
| `@SapXep` | `VARCHAR(20)` | `TEN`, `GIA_TANG`, `GIA_GIAM`, `TON_KHO` (giảm dần), `TON_KHO_TANG` (tăng dần). Mặc định theo tên |

Result set đầu tiên trả một dòng mỗi biến thể, với đúng tên cột `MaSanPham`, `MaBienTheNoiBo`, `TenSanPham`, `TenDanhMuc`, `TenThuongHieu`, `MauSac`, `KichCo`, `GiaBanRieng`, `TonKhoRieng`. Ứng dụng dùng cặp `(MaSanPham INT, MaBienTheNoiBo VARCHAR(20))` để sửa và xóa.

## Kiểm tra trên CSDL mẫu

- Lọc danh sách theo giá hoặc tồn kho. Thêm và sửa biến thể, thử mã trùng để xem thông báo CSDL. Trên CSDL mới nạp, có thể xóa một biến thể của sản phẩm 12. Thử xóa `(1, DEN-M)` để xem lỗi biến thể có trong đơn.
- Thống kê từ 01/01/2026 đến 18/11/2026 có 4 sản phẩm, tổng doanh thu 3.094.000 ₫. Bấm tiêu đề bảng để đổi thứ tự.
- Tính thanh toán đơn 4 cho kết quả 370.000 ₫. Mở trang Điểm khả dụng để tra điểm khách hàng theo trạng thái CSDL hiện tại.
