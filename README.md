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

Thứ tự dưới đây Hưng đã chốt ở T10 (23/11/2026). Các dòng "chưa có" là chỗ dành sẵn cho từng người.

| # | File | Nội dung | Người viết | Trạng thái |
|---|---|---|---|---|
| 11 | `11_ddl_nguoi_dung.sql` | Người dùng, vai trò, địa chỉ, nhân viên, danh mục (T11) | Hưng | đã viết |
| 12 | `12_ddl_san_pham.sql` | Sản phẩm, biến thể, bảng phụ (T12) | Hưng | đã viết |
| 13 | `13_ddl_don_hang_diem.sql` | Đơn hàng, chi tiết, giỏ, voucher, đánh giá, nhật ký, chính sách điểm, điểm danh (T13) | Đại | đã viết |
| 15 | `15_rang_buoc_lien_bang.sql` | Tuổi khách, total specialization, cây danh mục, địa chỉ (T15). Từ file này trở đi, người dùng chỉ được tạo qua `sp_TaoNguoiDung` | Hưng | đã viết |
| 20 | `20_function_view_diem.sql` | `fn_KiemTraVoucher`, `vw_TienDonHang`, `vw_DiemKhaDung`, `fn_TinhDiemKhaDung` (T23, T26, T27) | Đại | đã viết |
| 21 | `21_trigger_don_hang.sql` | Trigger quyền đánh giá (T24) và các trigger ràng buộc đơn hàng / voucher / chính sách | Đại | đã viết |
| 22 | `22_crud_bien_the.sql` | `sp_ThemBienThe`, `sp_SuaBienThe`, `sp_XoaBienThe` (T17–T19) | Đại | đã viết |
| 23 | `23_quy_trinh_don_hang.sql` | Điểm danh, tạo đơn, chuyển trạng thái / hủy đơn (T20–T22) | Đại | đã viết |
| 25 | `25_trigger_dan_xuat.sql` | Trigger `SAN_PHAM.TongSoLuongDaBan` (T25) | Hưng | chưa có |
| 28 | `28_sp_tim_bien_the.sql` | `sp_TimBienThe` — Q1 (T28) | Khanh | chưa có |
| 29 | `29_fn_tinh_tong_thanh_toan.sql` | `fn_TinhTongThanhToan` (T29) | Bằng | chưa có |
| 30 | `30_sp_thong_ke_ban.sql` | `sp_ThongKeBanTheoSanPham` — Q2 (T30) | Bằng | chưa có |
| 38 | `38_du_lieu_mau_nguoi_dung.sql` | Dữ liệu mẫu miền người dùng, vai trò, địa chỉ | Hưng | đã viết |
| 39 | `39_du_lieu_mau_san_pham.sql` | Dữ liệu mẫu miền danh mục, thương hiệu, sản phẩm, biến thể (T16) | Bằng | tạm (Hưng chuyển từ file 00 cũ; Bằng mở rộng) |
| 40 | `40_du_lieu_mau_don_hang_diem.sql` | Dữ liệu mẫu miền đơn hàng, điểm, voucher, đánh giá, nhật ký | Đại | đã viết |
| 90 | `90_kiem_thu_<mo_ta>.sql` | Kiểm thử, chạy theo thứ tự chữ cái. File chạy trước file khác không được để lại thay đổi dữ liệu (ca nào sửa dữ liệu thì bọc trong `BEGIN TRAN … ROLLBACK`) | theo module | có phần đơn hàng / điểm |
| 91, 92 | `91_…`, `92_…` | Kiểm thử đồng thời, chạy tay ở hai phiên | Đại | đã viết |

Mỗi miền dữ liệu mẫu một file (38 → 39 → 40, đúng thứ tự khóa ngoại). Bằng chịu trách nhiệm hợp nhất và bảo đảm mỗi bảng có ít nhất 5 dòng có nghĩa (T16). Dữ liệu mẫu chạy **sau** trigger để chính dữ liệu mẫu cũng được trigger kiểm tra.

> Lần chạy đầu trên SQL Server 2022 (23/11/2026, từ DB rỗng, còn dùng file tạm 00): mọi file chạy hết, `90_kiem_thu_don_hang_diem.sql` đạt 64/64 ca.

## Cài đặt và chạy

### 1. SQL Server trong Docker (Windows và Mac)

Cả nhóm chạy SQL Server 2022 trong Docker để mọi máy giống nhau. Cài và mở Docker Desktop, rồi đứng ở **thư mục gốc của repo** chạy:

```bash
export SQLCMDPASSWORD='<mật khẩu mạnh>'   # ≥ 8 ký tự, có chữ hoa, chữ thường, số, ký hiệu
docker run -d --name btl2-sql --platform linux/amd64 \
  -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD="$SQLCMDPASSWORD" \
  -e MSSQL_COLLATION=SQL_Latin1_General_CP1_CI_AS \
  -p 127.0.0.1:1433:1433 -v "$(pwd):/repo:ro" \
  mcr.microsoft.com/mssql/server:2022-latest
```

- **Windows (Git Bash):** chạy `export MSYS_NO_PATHCONV=1` trước mọi lệnh `docker`, và thay `$(pwd)` bằng `$(pwd -W)`.
- **Mac chip Apple:** bật "Use Rosetta for x86_64/amd64 emulation on Apple Silicon" trong Docker Desktop.
- Lần sau chỉ cần `docker start btl2-sql`. Mỗi lần mở terminal mới thì `export SQLCMDPASSWORD=...` lại.
- Muốn cài thẳng trên Windows thay vì Docker: SQL Server 2022 Developer, chọn **Custom**, collation `SQL_Latin1_General_CP1_CI_AS`, **Mixed Mode**.

### 2. Lệnh `q` để gọi sqlcmd

Chọn một trong hai cách, dán vào terminal (đứng ở thư mục gốc của repo):

```bash
# Cách 1 — dùng sqlcmd có sẵn trong container, không cần cài thêm (đã chạy thử trên Windows ngày 23/11/2026)
q() { docker exec -w /repo -e SQLCMDPASSWORD btl2-sql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -C -I "$@"; }

# Cách 2 — sqlcmd cài trên máy (Windows: winget install Microsoft.Sqlcmd; Mac: brew install sqlcmd)
q() { sqlcmd -S localhost -U sa -C -I "$@"; }
```

Cờ `-I` bắt buộc: sqlcmd bản cũ (gồm bản trong container) mặc định tắt `QUOTED_IDENTIFIER`, khi đó mọi INSERT vào `DIA_CHI` (bảng có index lọc) lỗi 1934. File lưu UTF-8 nên cần `-f 65001`.

### 3. Tạo lại DB rỗng và chạy toàn bộ

```bash
q -b -Q "IF DB_ID('BTL2') IS NOT NULL BEGIN ALTER DATABASE BTL2 SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE BTL2; END; CREATE DATABASE BTL2 COLLATE SQL_Latin1_General_CP1_CI_AS;"
for f in sql/[0-8]*.sql sql/90_*.sql; do echo "== $f"; q -d BTL2 -f 65001 -b -i "$f" || break; done
```

Kết quả đúng: vòng lặp chạy hết, cuối mỗi file kiểm thử có bảng tổng hợp `SoFail = 0`.

Công cụ giao diện: SSMS (Windows) hoặc VS Code + extension MSSQL / DBeaver (Mac), kết nối `localhost`, user `sa`, mở và Execute lần lượt từng file theo số. DB cần `COMPATIBILITY_LEVEL >= 130` (mặc định của SQL Server 2022 là 160).

## Quy ước chung

- **Hệ quản trị:** SQL Server 2022 (tối thiểu 2019), cả nhóm thống nhất ngày 23/11/2026. DB `BTL2` luôn tạo với collation `SQL_Latin1_General_CP1_CI_AS`, để máy Windows và Mac so chuỗi giống nhau.
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
| [docs/hungkhuu404-2311-handoff.md](docs/hungkhuu404-2311-handoff.md) | Bàn giao phần của Hưng cho cả nhóm: quy ước đã chốt ở T10, kết quả chạy thật, ai cần làm hoặc chờ gì |
