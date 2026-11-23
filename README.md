# Hệ thống thương mại điện tử B2C — BTL2 Hệ cơ sở dữ liệu

Môn Hệ cơ sở dữ liệu · Lớp L04 · Nhóm 07 · GVHD: thầy Dương Huỳnh Anh Đức
Trường Đại học Bách khoa — ĐHQG TP.HCM

Bài tập lớn 2 hiện thực cơ sở dữ liệu đã thiết kế ở BTL1 (đã chỉnh theo góp ý của giảng viên) trên **SQL Server**, gồm bảng, ràng buộc, dữ liệu mẫu, trigger, thủ tục, hàm và một ứng dụng kết nối CSDL. Chức năng xuyên suốt được chọn: **quản lý biến thể sản phẩm**.

## Thành viên

| Thành viên | Mảng phụ trách |
|---|---|
| Khưu Huỳnh Gia Hưng | CSDL, EERD, lược đồ, ràng buộc, trigger thuộc tính dẫn xuất |
| Võ Quốc Đại | Nghiệp vụ điểm, đơn hàng, CRUD biến thể |
| Lê Viễn Bằng | Backend, giao diện, tích hợp, dữ liệu mẫu |
| Hoàng Đình Vĩnh Khanh | Báo cáo PDF, đọc lại, kiểm thử tổng hợp |

Phân công chi tiết 48 đầu việc và tiến độ: [docs/phan-cong-va-tien-do.md](docs/phan-cong-va-tien-do.md).

## Cấu trúc thư mục

```
sql/     Script SQL, đánh số theo thứ tự chạy (bảng bên dưới)
docs/    Đặc tả nghiệp vụ, mô tả CSDL cho báo cáo, phân công – tiến độ
app/     Ứng dụng kết nối CSDL (Bằng — chưa có)
bao-cao/ Báo cáo sơ bộ, báo cáo cuối, hình EERD / lược đồ (Khanh — chưa có)
```

## Thứ tự chạy script SQL

Số thứ tự là **đề xuất**, Hưng chốt ở T10. Các dòng "chưa có" là chỗ dành sẵn cho từng người.

| # | File | Nội dung | Người viết | Trạng thái |
|---|---|---|---|---|
| 00 | `00_tam_bang_nguoi_dung_san_pham.sql` | Bảng tạm thay cho 11, 12 — **xóa khi có 11, 12** | Đại | tạm |
| 11 | `11_ddl_nguoi_dung.sql` | Người dùng, vai trò, địa chỉ, nhân viên, danh mục (T11) | Hưng | chưa có |
| 12 | `12_ddl_san_pham.sql` | Sản phẩm, biến thể, bảng phụ (T12) | Hưng | chưa có |
| 13 | `13_ddl_don_hang_diem.sql` | Đơn hàng, chi tiết, giỏ, voucher, đánh giá, nhật ký, chính sách điểm, điểm danh (T13) | Đại | đã viết |
| 15 | `15_rang_buoc_lien_bang.sql` | Tuổi khách, total specialization, cây danh mục, địa chỉ (T15) | Hưng | chưa có |
| 20 | `20_function_view_diem.sql` | `fn_KiemTraVoucher`, `vw_TienDonHang`, `vw_DiemKhaDung`, `fn_TinhDiemKhaDung` (T23, T26, T27) | Đại | đã viết |
| 21 | `21_trigger_don_hang.sql` | Trigger quyền đánh giá (T24) và các trigger ràng buộc đơn hàng / voucher / chính sách | Đại | đã viết |
| 22 | `22_crud_bien_the.sql` | `sp_ThemBienThe`, `sp_SuaBienThe`, `sp_XoaBienThe` (T17–T19) | Đại | đã viết |
| 23 | `23_quy_trinh_don_hang.sql` | Điểm danh, tạo đơn, chuyển trạng thái / hủy đơn (T20–T22) | Đại | đã viết |
| 25 | `25_trigger_dan_xuat.sql` | Trigger `SAN_PHAM.TongSoLuongDaBan` (T25) | Hưng | chưa có |
| 28 | `28_sp_tim_bien_the.sql` | `sp_TimBienThe` — Q1 (T28) | Khanh | chưa có |
| 29 | `29_fn_tinh_tong_thanh_toan.sql` | `fn_TinhTongThanhToan` (T29) | Bằng | chưa có |
| 30 | `30_sp_thong_ke_ban.sql` | `sp_ThongKeBanTheoSanPham` — Q2 (T30) | Bằng | chưa có |
| 40 | `40_du_lieu_mau_*.sql` | Dữ liệu mẫu theo miền; Bằng hợp nhất (T16) | cả nhóm | có miền đơn hàng / điểm |
| 90 | `90_kiem_thu_*.sql`, `91_…`, `92_…` | Kiểm thử | theo module | có phần đơn hàng / điểm |

Dữ liệu mẫu (40) chạy **sau** trigger để chính dữ liệu mẫu cũng được trigger kiểm tra.

> ⚠️ Các script hiện có **chưa được chạy trên SQL Server**, mới rà soát tĩnh. Cần chạy thử trên một DB thống nhất (mốc M2).

Chạy bằng `sqlcmd` (file lưu UTF-8 nên cần `-f 65001` để không lỗi tiếng Việt):

```bash
for f in sql/[0-8]*.sql sql/90_*.sql; do sqlcmd -S localhost -U sa -d BTL2 -f 65001 -b -i "$f" || break; done
```

Trong SSMS / Azure Data Studio: mở và Execute lần lượt từng file theo số. DB cần `COMPATIBILITY_LEVEL >= 130`.

## Quy ước chung

- **Hệ quản trị:** SQL Server 2019+ (Hưng xác nhận ở T10).
- **Tên file:** `NN_mo_ta_khong_dau.sql`, đầu file ghi mã việc và người viết. Mỗi người phải tự viết ít nhất một trigger / function / procedure — ghi rõ tên ở đầu đối tượng.
- **Biến thể sản phẩm** luôn định danh bằng cặp `(MaSanPham, MaBienTheNoiBo)`.
- **Trạng thái đơn** lưu bằng mã không dấu: `CHO_THANH_TOAN`, `CHO_XAC_NHAN`, `CHO_LAY_HANG`, `DANG_GIAO`, `DA_GIAO`, `DA_HUY`; giao diện tự hiển thị chữ có dấu.
- **Thời điểm** lưu theo giờ Việt Nam, lấy bằng `dbo.fn_ThoiDiemVN()`.
- **Lỗi nghiệp vụ** dùng `THROW` với thông báo tiếng Việt cụ thể; chia dải mã lỗi để không trùng:

  | Dải mã | Người |
  |---|---|
  | 50001 – 50199 | Đại (CRUD biến thể, đơn hàng, voucher, đánh giá, chính sách điểm) |
  | 50200 – 50399 | Hưng |
  | 50400 – 50599 | Bằng |
  | 50600 – 50799 | Khanh |

- **Làm việc với Git:** mỗi người làm trên nhánh riêng (ví dụ `hung/ddl-nguoi-dung`), mở Pull Request vào `main`, người kiểm tra chéo theo bảng phân công duyệt trước khi gộp.

## Tài liệu

| Tài liệu | Nội dung |
|---|---|
| [docs/phan-cong-va-tien-do.md](docs/phan-cong-va-tien-do.md) | 48 đầu việc, trạng thái, bàn giao giữa các thành viên |
| [docs/dac-ta-nghiep-vu-diem.md](docs/dac-ta-nghiep-vu-diem.md) | T03 — công thức điểm, voucher, hủy đơn, ví dụ tính tay |
| [docs/csdl-don-hang-diem.md](docs/csdl-don-hang-diem.md) | Mô tả bảng / routine đơn hàng – điểm – biến thể và data dictionary để đưa vào báo cáo |
