# T03 — Đặc tả nghiệp vụ điểm, giảm giá và hủy đơn

> Người phụ trách: **Võ Quốc Đại** · Người rà văn bản: Khanh · Kiểm tra khả thi UI: Bằng
> Căn cứ: Tài liệu 1 — Điều chỉnh BTL1 (mục 2–4). Hiện thực ở `sql/dai/20_View_Function_Diem.sql`, `sql/dai/23_QuyTrinh_DonHang.sql`.
>
> **Lưu ý:** các con số chính sách (1%, 100đ/điểm, 30%, 5 điểm/ngày) là **đề xuất của nhóm** để minh họa và kiểm thử,
> không phải chính sách chính thức của Shopee hay dữ liệu từ đề bài. Cần xác nhận với giảng viên nếu lớp quy định khác.

## 1. Điểm tích lũy là thuộc tính dẫn xuất

`KHACH_HANG` **không lưu** số dư điểm. Điểm khả dụng của khách *k* luôn được tính lại từ lịch sử:

```
DiemKhaDung(k) =   Σ E(đơn)  với các đơn của k đang ở trạng thái DA_GIAO
                 + Σ L(lần điểm danh) của k
                 − Σ U(đơn)  với các đơn của k KHÔNG ở trạng thái DA_HUY
```

Hiện thực: `vw_DiemKhaDung` (view, T26) và `fn_TinhDiemKhaDung(@MaKhachHang)` (hàm có cursor, T27). Hai cách phải cho cùng kết quả (ca kiểm thử A2, H1).

Vì không có cột số dư nên **không có thao tác "cộng hoàn" nào**: khi hủy đơn, đơn chuyển sang `DA_HUY` và tự rơi khỏi tổng trừ ⇒ không thể hoàn điểm hai lần.

## 2. Chính sách điểm có phiên bản

Bảng `CHINH_SACH_DIEM(MaChinhSach, TenChinhSach, HieuLucTu, HieuLucDen, TyLeTichDiem, GiaTriMotDiem, TyLeGiamToiDa, DiemThuongDangNhap)`.

| Ký hiệu | Cột | Ý nghĩa | Giá trị đề xuất hiện hành |
|---|---|---|---|
| r | `TyLeTichDiem` | Tỷ lệ tiền hàng thực trả được quy thành điểm | 0,01 = 1% |
| v | `GiaTriMotDiem` | Số tiền tương ứng 1 điểm | 100 đ/điểm |
| c | `TyLeGiamToiDa` | Tỷ lệ tối đa của tiền hàng sau voucher được trả bằng điểm | 0,30 = 30% |
| L | `DiemThuongDangNhap` | Điểm cho lần đăng nhập hợp lệ đầu tiên trong ngày | 5 điểm/ngày |

Quy tắc:
- Khoảng hiệu lực nửa mở `[HieuLucTu, HieuLucDen)`; `HieuLucDen = NULL` là chưa kết thúc. Các phiên bản **không chồng lấn** (trigger `trg_ChinhSachDiem_KiemTra`).
- Đơn hàng chốt phiên bản tại lúc đặt (`DON_HANG.MaChinhSachDiemChot`), điểm danh chốt phiên bản tại lúc đăng nhập (`DIEM_DANH_DANG_NHAP.MaChinhSachDiemChot`).
- Phiên bản đã được chốt thì **không được sửa r, v, c, L**; muốn đổi chính sách ⇒ đóng phiên bản cũ (đặt `HieuLucDen`) và thêm phiên bản mới. Nhờ vậy đơn cũ không bị ảnh hưởng (ca kiểm thử F1–F3).
- Thay cột mơ hồ `TyLeQuyDoiDiemChot` của BTL1 bằng khóa ngoại phiên bản chính sách.

## 3. Công thức một đơn hàng

| Ký hiệu | Công thức | Ghi chú |
|---|---|---|
| H | Σ (SoLuongMua × DonGiaLucDat) | Tổng tiền hàng, giá chốt lúc đặt |
| V | Σ TienGiamChot | Tổng giảm thực tế của các voucher, 0 ≤ V ≤ H |
| U | DiemSuDung | Số nguyên ≥ 0 |
| G | U × v | Tiền giảm bằng điểm |
| A | H − V − G | Tiền hàng thực trả |
| F | PhiVanChuyenChot | Điểm **không** giảm phí vận chuyển |
| T | H − V − U×v + F = A + F | Tổng thanh toán (dẫn xuất, không lưu) |
| E | FLOOR(A × r / v) | Điểm mua hàng, chỉ ghi nhận khi đơn `DA_GIAO` |
| Tỷ lệ giảm bằng điểm | G / (H − V) × 100% | Làm tròn 2 chữ số thập phân để hiển thị |

**Giới hạn điểm sử dụng:** `0 ≤ U ≤ MIN( DiemKhaDungTruocDat , FLOOR(c × (H − V) / v) )`.

**Quy tắc làm tròn:** U là số nguyên; trần điểm và E đều làm tròn **xuống** (FLOOR) ⇒ khách không bao giờ được giảm quá c, và hệ thống không bao giờ thưởng dư. Tiền lưu `DECIMAL(14,2)`.

Hiện thực: `vw_TienDonHang` trả về đủ H, V, U, G, F, A, T, E dự kiến, E đã nhận, tỷ lệ giảm cho từng đơn.

## 4. Nhiều voucher trên một đơn

- Mỗi voucher chỉ áp dụng một lần trong một đơn (PK `(MaDonHang, MaVoucher)`).
- Điều kiện từng voucher (`fn_KiemTraVoucher`): tồn tại; `NgayBatDau ≤ NgayDatHang ≤ NgayKetThuc` (RB8); `H ≥ GiaTriDonToiThieu` (RB5).
- Áp voucher có giá trị lớn trước; tiền giảm của voucher = `MIN(GiaTriGiamGia, H − tổng đã giảm trước đó)` ⇒ `TienGiamChot ≤ GiaTriGiamGia` và `V ≤ H` (RB6). Voucher không còn tác dụng (giảm 0đ) bị từ chối để khách bỏ ra.
- Trigger `trg_ApDungKhuyenMai_KiemTra` kiểm tra lại RB5, RB6, RB8 ở mức CSDL.

## 5. Thời điểm ghi nhận

| Sự kiện | Điều xảy ra với điểm | Ở đâu |
|---|---|---|
| Đăng nhập thành công **lần đầu trong ngày (giờ VN)** | +L theo chính sách hiệu lực lúc đăng nhập; các lần sau trong ngày +0 | `sp_DiemDanhDangNhap` (T20), PK `(MaKhachHang, NgayTinhThuongVN)` |
| Đặt đơn | U bị giữ (trừ khỏi khả dụng) ngay khi đơn được tạo | `sp_TaoDonHang` (T21) |
| Đơn chuyển sang `DA_GIAO` | +E của đơn | `sp_CapNhatTrangThaiDon` (T22) → view/hàm tự tính |
| Đơn bị hủy hợp lệ (trước `DANG_GIAO`) | U của đơn không còn bị trừ; không cộng lần hai | `sp_CapNhatTrangThaiDon` (T22) |

"Ngày" thưởng đăng nhập tính theo giờ Việt Nam (UTC+7): toàn bộ thời điểm trong CSDL được lưu theo giờ VN (`fn_ThoiDiemVN()`).

**Chống tiêu vượt khi hai phiên đặt cùng lúc:** `sp_TaoDonHang` khóa dòng `KHACH_HANG` của khách bằng `UPDLOCK, HOLDLOCK` trước khi tính điểm khả dụng ⇒ các giao dịch tiêu điểm của cùng khách chạy tuần tự (kiểm thử `91_DongThoi_PhienA.sql` + `92_DongThoi_PhienB.sql`).

## 6. Ví dụ tính tay (khớp dữ liệu mẫu đơn số 4 và ca kiểm thử A1, C12)

Chính sách 5: r = 1%, v = 100 đ/điểm, c = 30%. Khách KH1 có 2.000+ điểm khả dụng.

| Khoản mục | Tính | Giá trị |
|---|---|---|
| Tổng tiền hàng H | 1 × 350.000 (củ sạc) + 1 × 150.000 (cáp 2m) | 500.000 đ |
| Voucher V | GIAM50K | 50.000 đ |
| Phí vận chuyển F | "Nhanh" | 20.000 đ |
| Trần điểm | FLOOR(0,30 × 450.000 / 100) | 1.350 điểm |
| Điểm dùng U | 1.000 ≤ MIN(2.000, 1.350) ✓ | 1.000 điểm |
| Tiền giảm bằng điểm G | 1.000 × 100 | 100.000 đ |
| Tiền hàng thực trả A | 500.000 − 50.000 − 100.000 | 350.000 đ |
| **Tổng thanh toán T** | 350.000 + 20.000 | **370.000 đ** |
| **Điểm nhận khi giao E** | FLOOR(350.000 × 0,01 / 100) = FLOOR(35) | **35 điểm** |
| Tỷ lệ giảm thực tế bằng điểm | 100.000 / 450.000 | 22,22% |

### Ca biên 1 — vượt trần 30%
Đơn 1 cáp 1m: H = 120.000, V = 0 ⇒ trần = FLOOR(0,30 × 120.000 / 100) = **360 điểm**. Khách có 1.073 điểm nhưng muốn dùng 500 ⇒ bị từ chối (lỗi 50120, ca C1).

### Ca biên 2 — hủy đơn
KH2 có 49 điểm, đặt 2 cáp 1m (H = 240.000) dùng U = 40 ⇒ khả dụng còn 9, tồn kho −2.
Khách hủy khi đơn đang `CHO_XAC_NHAN` ⇒ khả dụng trở lại 49, tồn kho +2. Hủy lần hai ⇒ lỗi 50134, tồn kho và điểm không đổi (ca E1–E4).

### Ca biên 3 — làm tròn E
Đơn mẫu 1: H = 398.000, V = 15.000, U = 0 ⇒ A = 383.000 ⇒ E = FLOOR(383.000 × 0,01 / 100) = FLOOR(38,3) = **38**.

## 7. Bảng điểm kỳ vọng của dữ liệu mẫu

| Khách | Nguồn | Điểm khả dụng |
|---|---|---|
| KH1 | 4 lần đăng nhập tuần khai trương × 500 + E(đơn 1) 38 + E(đơn 4) 35 − U(đơn 4) 1.000 | 1.073 |
| KH2 | E(đơn 2) 89 + 2 × 5 − U(đơn 8) 50 | 49 |
| KH3 | E(đơn 3) 129 + 5 | 134 |
| KH4 | 3 × 10 (chính sách 4) − 0 (đơn 6 đã hủy, 20 điểm được giải phóng) | 30 |
| KH6 | — | 0 |

## 8. Thay thế ràng buộc BTL1 (để Khanh sửa ở T09)

- **RB11 cũ** ("DiemTichLuy giảm khi đặt, cộng lại khi hủy") ⇒ thay bằng: *"DiemSuDung của đơn không vượt quá điểm khả dụng của khách tại thời điểm đặt (tính theo mục 1) và không vượt FLOOR(c × (H − V) / v) theo chính sách chốt của đơn; điểm của đơn bị hủy tự động không còn bị trừ."*
- **RB17 cũ** ("DiemSuDung × TyLeQuyDoiDiemChot ≤ …") ⇒ thay bằng: *"G = U × v ≤ c × (H − V) ≤ H − V nên A ≥ 0 và T = A + F ≥ 0."*
- Mục 3.1 bước 9 (thuộc tính dẫn xuất): công thức tổng tiền đổi thành `T = H − V − U × v + F`, với v lấy từ chính sách chốt.
