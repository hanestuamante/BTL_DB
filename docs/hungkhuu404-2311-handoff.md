# Bàn giao phần CSDL người dùng – sản phẩm (Hưng) cho cả nhóm

> Người viết: Khưu Huỳnh Gia Hưng (GitHub `hungkhuu404`). Bản ngày 23/11/2026, cập nhật mỗi khi phần của Hưng đổi trạng thái.
> Đọc file này nếu bạn là Đại, Bằng hoặc Khanh và cần biết: nhóm đã chốt gì ở T10, phần của Hưng tới đâu, và bạn cần làm hoặc chờ gì.

## 1. Đã chốt ở T10 (áp dụng cho cả nhóm)

| Nội dung | Quy ước | Vì sao |
|---|---|---|
| Hệ quản trị | **SQL Server 2022** (tối thiểu 2019) | Cả nhóm thống nhất ngày 23/11/2026; code đã viết là T-SQL của SQL Server |
| Cách cài | SQL Server trong **Docker**, cùng một lệnh cho Windows và Mac (README, mục "Cài đặt và chạy") | Mọi máy cùng phiên bản, cùng cấu hình |
| Collation của DB | `SQL_Latin1_General_CP1_CI_AS`, ghi cố định trong lệnh tạo DB | Nếu để mặc định, máy Windows tiếng Việt sẽ ra `Vietnamese_CI_AS` và so chuỗi khác máy Mac |
| Cờ `-I` của sqlcmd | **Luôn có** | sqlcmd bản cũ mặc định tắt `QUOTED_IDENTIFIER`; thiếu `-I` thì mọi INSERT vào `DIA_CHI` lỗi 1934 (đã thử: không có `-I` ra 0, có `-I` ra 1) |
| Lệnh chạy | Hàm `q` trong README, rồi "Tạo lại DB" và "Chạy toàn bộ" | Một lệnh chung để mọi người so kết quả |
| Dữ liệu mẫu | Mỗi miền một file: `38` người dùng (Hưng), `39` sản phẩm (Bằng), `40` đơn hàng – điểm (Đại) | Nếu cùng tên `40_du_lieu_mau_*`, file chạy theo thứ tự chữ cái nên dữ liệu đơn hàng sẽ chạy trước người dùng và vỡ khóa ngoại |
| File kiểm thử | `90_kiem_thu_<mo_ta>.sql`, chạy theo thứ tự chữ cái; file chạy trước file khác không được để lại thay đổi dữ liệu | File của Đại chạy cuối và cần dữ liệu mẫu còn nguyên |
| Tạo người dùng | Sau khi có file `15`, **chỉ qua `sp_TaoNguoiDung`**; INSERT thẳng vào `NGUOI_DUNG` bị trigger chặn (lỗi 50223) | Bảo đảm mỗi người dùng luôn là khách hàng hoặc nhân viên (total specialization) |
| Mã lỗi | Hưng dùng 50200 – 50399 | Theo bảng dải mã trong README |

## 2. Kết quả chạy thật lần đầu (23/11/2026)

Chạy trên SQL Server 2022 trong Docker, từ DB rỗng, theo đúng lệnh của README (vẫn dùng file tạm `00`):

- Mọi file từ `00` tới `90` chạy hết, không có lỗi.
- `90_kiem_thu_don_hang_diem.sql`: **64/64 ca PASS**. Đây là "mốc" để so: sau mỗi thay đổi của Hưng, file này phải vẫn ra 64/64.
- DB có 22 bảng, 26 khóa ngoại; tiếng Việt đọc đúng (`UNICODE(N'Đ')` = 272).
- Bảng còn dưới 5 dòng dữ liệu: `GIO_HANG` (0 dòng) và `NHAN_VIEN` (3 dòng). Hưng thêm 2 nhân viên ở file `38`; `GIO_HANG` thuộc miền của Bằng (T16).

Sau bước 3 (DDL thật thay file `00`): `90_kiem_thu_cau_truc_rang_buoc.sql` đạt 29/29 ca, file của Đại vẫn 64/64.
Sau bước 4 (ràng buộc liên bảng, `sp_TaoNguoiDung`): file kiểm thử của Hưng đạt 46/46, file của Đại vẫn 64/64.
Sau bước 5 (trigger T25): `90_kiem_thu_dan_xuat_nghiep_vu.sql` đạt 15/15. Sau khi cả 64 ca của Đại chạy xong (tạo, giao, hủy đơn thật), `TongSoLuongDaBan` của cả 6 sản phẩm vẫn bằng giá trị tính lại.
Kiểm thử hai phiên `91` + `92` của Đại: phiên B bị chặn 17 giây rồi bị từ chối 50119, KH1 còn 73 điểm, đúng kỳ vọng.

## 3. Phần của Hưng: thứ tự làm và trạng thái

| Bước | Việc | Kết quả để nhóm dùng | Trạng thái |
|---|---|---|---|
| 1 | T10: chốt hệ quản trị, thứ tự file, lệnh chạy; chạy thử code hiện có | README mới, mốc 64/64 | ✅ (chờ PR) |
| 2 | T04, T05, T07, T08: thiết kế 10 bảng, data dictionary (mốc M1) | `docs/csdl-nguoi-dung-san-pham.md` | ✅ (chờ Đại, Khanh rà) |
| 3 | T11, T12, T14: DDL thật, dữ liệu `38`, `39` tạm, **xóa file `00`** | `sql/11_…`, `12_…`, `38_…`, `39_…`, kiểm thử `90_kiem_thu_cau_truc_rang_buoc.sql` | ✅ (chờ PR) |
| 4 | T15, T35: ràng buộc liên bảng, `sp_TaoNguoiDung` | `sql/15_rang_buoc_lien_bang.sql`; file `38` đổi sang gọi `sp_TaoNguoiDung` | ✅ (chờ PR) |
| 5 | T25, T37: trigger `TongSoLuongDaBan`, kiểm thử trigger | `sql/25_trigger_dan_xuat.sql`, kiểm thử `90_kiem_thu_dan_xuat_nghiep_vu.sql` | ✅ (chờ PR) |
| 6 | T06, T07: EERD và hình lược đồ 22 bảng | `bao-cao/hinh/` | ⬜ |
| 7 | Chạy toàn bộ từ DB rỗng (M2), review T21, mở PR | PR vào `main`, issue review cho Đại | ⬜ |

## 4. Mỗi người cần làm hoặc chờ gì

### Cả nhóm
- Cài theo README, mục "Cài đặt và chạy", rồi chạy "Tạo lại DB" và "Chạy toàn bộ". Kết quả đúng là 64/64 ở file của Đại. Ra khác thì báo Hưng kèm ảnh chụp phần lỗi.

### Đại
- Không cần sửa code. File `00` đã bị xóa ở bước 3; chú thích ở `sql/13_ddl_don_hang_diem.sql` dòng 7 và `sql/40_du_lieu_mau_don_hang_diem.sql` dòng 10 còn nhắc file `00`, Đại sửa lại cho khớp (dữ liệu người dùng giờ ở `38`, sản phẩm ở `39`, mã giữ nguyên).
- Bước 2 xong thì rà `docs/csdl-nguoi-dung-san-pham.md` (M1): khóa, kiểu cột và tên ràng buộc có khớp file `13` và các routine không.
- Bước 7: Hưng mở issue review T21 (`sp_TaoDonHang`, `sp_CapNhatTrangThaiDon`) theo 5 điểm: rollback, thứ tự khóa, địa chỉ ghép, khóa ghép biến thể, tổng thanh toán không âm.
- Code của Đại đã chạy thật lần đầu ngày 23/11 và đạt 64/64, `91` + `92` cũng đạt. Đại cập nhật cột trạng thái phần mình trong `docs/phan-cong-va-tien-do.md` (dòng chú thích "chưa chạy trên SQL Server" đã cũ).

### Bằng
- File `39_du_lieu_mau_san_pham.sql` đã có dữ liệu danh mục, thương hiệu, sản phẩm, hình ảnh, biến thể (chuyển nguyên từ file `00`). Bằng mở rộng file này ở T16, giữ nguyên ID 1–6 của sản phẩm và 10 biến thể, vì file `40` của Đại dựa vào chúng.
- `GIO_HANG` hiện chưa có dòng nào; cần ít nhất 5 dòng ở T16.
- Dữ liệu người dùng mới (nếu cần) phải gọi `EXEC dbo.sp_TaoNguoiDung …` thay vì INSERT thẳng.

### Khanh
- **Chờ bước 2:** mục "Thay đổi so với BTL1" trong `docs/csdl-nguoi-dung-san-pham.md` liệt kê những đoạn BTL1 cần sửa ở T09 (20 → 22 bảng, bỏ `DiemTichLuy`, biến thể thành thực thể yếu, `TongSoLuongDaBan` được lưu bằng trigger).
- Về số ràng buộc: bản PDF BTL1 trên máy Hưng có 16 ràng buộc ở mục 1.4. Tài liệu phân công ghi 17 vì bản BTL1 đã chỉnh có thêm RB17 về điểm; RB17 thuộc phần của Đại, câu thay thế ở `docs/dac-ta-nghiep-vu-diem.md` mục 8.
- **Chờ bước 6:** hình EERD và lược đồ quan hệ ở `bao-cao/hinh/` để chèn vào báo cáo (T44).
