/* =====================================================================
   30_DuLieuMau_Dai.sql — Dữ liệu mẫu miền của Đại (theo bảng phân chia dữ liệu mẫu)
   Bảng: CHINH_SACH_DIEM, DIEM_DANH_DANG_NHAP, PHUONG_THUC_VAN_CHUYEN, PHUONG_THUC_THANH_TOAN,
         KHUYEN_MAI, DON_HANG, CHI_TIET_DON_HANG, AP_DUNG_KHUYEN_MAI, NHAT_KY_XU_LY_DON,
         DANH_GIA, TEP_DANH_GIA (≥ 5 dòng có nghĩa mỗi bảng).
   GIO_HANG thuộc miền dữ liệu của Bằng (T16) → không nạp ở đây.

   Chạy NGAY SAU 13 → 20 → 21 → 22 → 23 trên các bảng rỗng (trigger đã có ⇒ dữ liệu mẫu cũng
   phải qua kiểm tra của trigger). Muốn nạp lại: chạy lại từ 13 (nhật ký không cho DELETE).
   ID khách / nhân viên / địa chỉ / biến thể lấy theo 00_TAM_...; khi Bằng hợp nhất (T16)
   cần đổi cho khớp dữ liệu thật.

   Điểm khả dụng KỲ VỌNG sau khi nạp (kiểm thử ở 90_KiemThu_Dai.sql):
     KH1 = 4×500 (đăng nhập khai trương) + 38 (đơn 1) + 35 (đơn 4) − 1000 (đơn 4) = 1073
     KH2 = 89 (đơn 2) + 2×5 (đăng nhập) − 50 (đơn 8)                              =   49
     KH3 = 129 (đơn 3) + 5 (đăng nhập)                                             =  134
     KH4 = 3×10 (đăng nhập) − 0 (đơn 6 đã hủy, 20 điểm được giải phóng)             =   30
     KH6 = 0
   Đơn 4 là đúng VÍ DỤ TÍNH TAY trong tài liệu điều chỉnh: H=500.000, V=50.000, U=1.000,
   F=20.000 ⇒ G=100.000, T=370.000, E=35, tỷ lệ giảm bằng điểm 22,22%.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------- CHÍNH SÁCH ĐIỂM (các phiên bản liên tiếp, không chồng lấn) ---------- */
INSERT dbo.CHINH_SACH_DIEM (MaChinhSach, TenChinhSach, HieuLucTu, HieuLucDen, TyLeTichDiem, GiaTriMotDiem, TyLeGiamToiDa, DiemThuongDangNhap) VALUES
 (1, N'Khai trương: thưởng đăng nhập 500 điểm/ngày', '2025-01-01 00:00', '2025-01-08 00:00', 0.0100, 100, 0.3000, 500),
 (2, N'Chuẩn nửa đầu 2025',                          '2025-01-08 00:00', '2025-07-01 00:00', 0.0100, 100, 0.3000,   5),
 (3, N'Tích điểm x2 nửa cuối 2025',                  '2025-07-01 00:00', '2026-01-01 00:00', 0.0200, 100, 0.3000,   5),
 (4, N'Chuẩn nửa đầu 2026 (giảm tối đa 25%)',        '2026-01-01 00:00', '2026-07-01 00:00', 0.0100, 100, 0.2500,  10),
 (5, N'Chuẩn hiện hành (theo tài liệu điều chỉnh)',  '2026-07-01 00:00', NULL,               0.0100, 100, 0.3000,   5);

/* ---------- PHƯƠNG THỨC VẬN CHUYỂN / THANH TOÁN ---------- */
INSERT dbo.PHUONG_THUC_VAN_CHUYEN (MaPhuongThucVC, TenPhuongThucVC, PhiVanChuyenThamChieu, ThoiLuongGiaoDuKien) VALUES
 (1, N'Tiết kiệm',                 15000, 5),
 (2, N'Nhanh',                     20000, 3),
 (3, N'Hỏa tốc',                   45000, 1),
 (4, N'Giao trong ngày nội thành', 35000, 1),
 (5, N'Hàng cồng kềnh',            60000, 7);

INSERT dbo.PHUONG_THUC_THANH_TOAN (MaPhuongThucTT, TenPhuongThucTT, LaThanhToanKhiNhan) VALUES
 (1, N'Thanh toán khi nhận hàng (COD)', 1),
 (2, N'Ví điện tử',                     0),
 (3, N'Thẻ tín dụng / ghi nợ',          0),
 (4, N'Chuyển khoản ngân hàng',         0),
 (5, N'Quét mã QR',                     0);

/* ---------- KHUYẾN MÃI ---------- */
INSERT dbo.KHUYEN_MAI (MaVoucher, TenChuongTrinh, GiaTriGiamGia, GiaTriDonToiThieu, NgayBatDau, NgayKetThuc) VALUES
 ('GIAM15K',    N'Giảm 15K mọi đơn năm 2026',                15000,       0, '2026-01-01 00:00', '2026-12-31 23:59:59'),
 ('GIAM50K',    N'Giảm 50K cho đơn từ 300K (tháng 11–12)',   50000,  300000, '2026-11-01 00:00', '2026-12-31 23:59:59'),
 ('TET2026',    N'Lì xì Tết 2026',                          100000,  500000, '2026-01-20 00:00', '2026-02-20 23:59:59'),
 ('SALE1111',   N'Siêu sale 11.11',                         111000, 1000000, '2026-11-10 00:00', '2026-11-12 23:59:59'),
 ('HETHAN01',   N'Ưu đãi tháng 6/2025 (đã hết hạn)',         30000,  100000, '2025-06-01 00:00', '2025-06-30 23:59:59'),
 ('KHAITRUONG', N'Mừng khai trương',                         20000,  100000, '2025-01-01 00:00', '2025-01-07 23:59:59');

/* ---------- ĐIỂM DANH ĐĂNG NHẬP ---------- */
INSERT dbo.DIEM_DANH_DANG_NHAP (MaKhachHang, NgayTinhThuongVN, ThoiDiemDangNhap, MaChinhSachDiemChot) VALUES
 (1, '2025-01-01', '2025-01-01 08:15', 1),
 (1, '2025-01-02', '2025-01-02 09:00', 1),
 (1, '2025-01-03', '2025-01-03 07:30', 1),
 (1, '2025-01-04', '2025-01-04 20:10', 1),
 (4, '2026-03-01', '2026-03-01 08:00', 4),
 (4, '2026-03-02', '2026-03-02 08:05', 4),
 (4, '2026-03-03', '2026-03-03 21:00', 4),
 (2, '2026-11-20', '2026-11-20 10:00', 5),
 (2, '2026-11-21', '2026-11-21 11:00', 5),
 (3, '2026-11-22', '2026-11-22 09:00', 5);
GO

/* ---------- ĐƠN HÀNG (đủ các trạng thái) ---------- */
SET IDENTITY_INSERT dbo.DON_HANG ON;
INSERT dbo.DON_HANG (MaDonHang, NgayDatHang, TrangThaiDon, NgayGiaoDuKien, DiemSuDung, PhiVanChuyenChot, LoiNhanNguoiBan,
                     TenNguoiNhan, DiaChiGiaoHang, SdtNguoiNhan, MaKhachHang, MaDiaChi, MaPhuongThucVC, MaPhuongThucTT, MaChinhSachDiemChot) VALUES
 (1, '2026-02-05 10:00', 'DA_GIAO',      '2026-02-08',    0, 20000, N'Giao giờ hành chính',
     N'Nguyễn Văn An',       N'268 Lý Thường Kiệt, Phường Diên Hồng, TP. Hồ Chí Minh', '0901000001', 1, 1, 2, 1, 4),
 (2, '2026-03-10 19:30', 'DA_GIAO',      '2026-03-15',    0, 15000, NULL,
     N'Trần Thị Bình',       N'12A Nguyễn Trãi, Phường Bến Thành, TP. Hồ Chí Minh',     '0901000002', 2, 2, 1, 3, 4),
 (3, '2026-06-10 08:00', 'DA_GIAO',      '2026-06-15',    0, 15000, N'Gọi trước khi giao',
     N'Lê Minh Chi',         N'45 Trần Phú, Phường Hải Châu, TP. Đà Nẵng',               '0901000003', 3, 3, 1, 1, 4),
 (4, '2026-11-15 09:00', 'DA_GIAO',      '2026-11-18', 1000, 20000, NULL,
     N'Nguyễn Văn An (KTX)', N'KTX B Tô Vĩnh Diện, Phường Linh Xuân, TP. Hồ Chí Minh',   '0901000001', 1, 6, 2, 2, 5),
 (5, '2026-11-20 14:00', 'DANG_GIAO',    '2026-11-21',    0, 45000, N'Cần gấp cho chuyến công tác',
     N'Lê Minh Chi',         N'45 Trần Phú, Phường Hải Châu, TP. Đà Nẵng',               '0901000003', 3, 3, 3, 1, 5),
 (6, '2026-11-21 21:00', 'DA_HUY',       '2026-11-26',   20, 15000, NULL,
     N'Phạm Quốc Dũng',      N'7 Hai Bà Trưng, Phường Hoàn Kiếm, TP. Hà Nội',            '0901000004', 4, 4, 1, 4, 5),
 (7, '2026-11-22 10:00', 'CHO_XAC_NHAN', '2026-11-25',    0, 20000, NULL,
     N'Võ Trường Giang',     N'101 Võ Văn Ngân, Phường Thủ Đức, TP. Hồ Chí Minh',        '0901000006', 6, 5, 2, 1, 5),
 (8, '2026-11-22 16:00', 'CHO_LAY_HANG', '2026-11-25',   50, 20000, N'Gói quà giúp mình',
     N'Trần Thị Bình',       N'12A Nguyễn Trãi, Phường Bến Thành, TP. Hồ Chí Minh',     '0901000002', 2, 2, 2, 3, 5);
SET IDENTITY_INSERT dbo.DON_HANG OFF;
GO

/* ---------- CHI TIẾT ĐƠN HÀNG (đơn giá & phân loại chốt lúc đặt) ---------- */
INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot, MaSanPham, MaBienTheNoiBo) VALUES
 (1, 1, 2, 199000, N'Đen',       N'M',   1, 'DEN-M'),
 (2, 1, 1, 899000, N'Xám',       N'41',  2, 'XAM-41'),
 (3, 1, 1, 899000, N'Xám',       N'40',  2, 'XAM-40'),
 (3, 2, 2, 199000, N'Đen',       N'L',   1, 'DEN-L'),
 (4, 1, 1, 350000, N'Trắng',     N'20W', 3, 'TRANG-20W'),
 (4, 2, 1, 150000, N'Đen',       N'2m',  5, 'DEN-2M'),
 (5, 1, 1, 590000, N'Xanh navy', N'L',   4, 'XANH-L'),
 (6, 1, 3, 120000, N'Đen',       N'1m',  5, 'DEN-1M'),
 (7, 1, 1, 189000, N'Trắng',     N'M',   1, 'TRANG-M'),
 (7, 2, 1, 120000, N'Đen',       N'1m',  5, 'DEN-1M'),
 (8, 1, 2, 199000, N'Đen',       N'L',   1, 'DEN-L');
GO

/* ---------- ÁP DỤNG KHUYẾN MÃI (trigger kiểm tra RB5, RB6, RB8) ---------- */
INSERT dbo.AP_DUNG_KHUYEN_MAI (MaDonHang, MaVoucher, TienGiamChot) VALUES
 (1, 'GIAM15K', 15000),
 (4, 'GIAM50K', 50000),
 (5, 'GIAM50K', 50000),
 (7, 'GIAM15K', 15000),
 (8, 'GIAM50K', 50000),
 (8, 'GIAM15K', 15000);
GO

/* ---------- NHẬT KÝ XỬ LÝ ĐƠN (khớp trạng thái hiện tại của từng đơn) ----------
   NV01 = người dùng 4 (vừa là khách hàng KH4) → không xử lý đơn 6 của chính mình (RB16). */
INSERT dbo.NHAT_KY_XU_LY_DON (ThoiDiem, ThaoTac, TrangThaiTruoc, TrangThaiSau, GhiChu, MaDonHang, NguonThaoTac, MaNhanVien) VALUES
 -- Đơn 1 (COD)
 ('2026-02-05 10:00', N'Tạo đơn hàng',                 NULL,             'CHO_XAC_NHAN', NULL, 1, 'HeThong',  NULL),
 ('2026-02-05 14:00', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 1, 'NhanVien', 'NV02'),
 ('2026-02-06 09:00', N'Bàn giao đơn vị vận chuyển',   'CHO_LAY_HANG',   'DANG_GIAO',    NULL, 1, 'NhanVien', 'NV02'),
 ('2026-02-08 16:00', N'Giao hàng thành công',         'DANG_GIAO',      'DA_GIAO',      NULL, 1, 'NhanVien', 'NV03'),
 -- Đơn 2 (thẻ)
 ('2026-03-10 19:30', N'Tạo đơn hàng',                 NULL,             'CHO_THANH_TOAN', NULL, 2, 'HeThong', NULL),
 ('2026-03-10 19:31', N'Xác nhận thanh toán',          'CHO_THANH_TOAN', 'CHO_XAC_NHAN', NULL, 2, 'HeThong',  NULL),
 ('2026-03-11 08:30', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 2, 'NhanVien', 'NV01'),
 ('2026-03-11 15:00', N'Bàn giao đơn vị vận chuyển',   'CHO_LAY_HANG',   'DANG_GIAO',    NULL, 2, 'NhanVien', 'NV02'),
 ('2026-03-14 10:00', N'Giao hàng thành công',         'DANG_GIAO',      'DA_GIAO',      NULL, 2, 'NhanVien', 'NV03'),
 -- Đơn 3 (COD)
 ('2026-06-10 08:00', N'Tạo đơn hàng',                 NULL,             'CHO_XAC_NHAN', NULL, 3, 'HeThong',  NULL),
 ('2026-06-10 13:00', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 3, 'NhanVien', 'NV02'),
 ('2026-06-11 09:00', N'Bàn giao đơn vị vận chuyển',   'CHO_LAY_HANG',   'DANG_GIAO',    NULL, 3, 'NhanVien', 'NV02'),
 ('2026-06-14 17:00', N'Giao hàng thành công',         'DANG_GIAO',      'DA_GIAO',      NULL, 3, 'NhanVien', 'NV03'),
 -- Đơn 4 (ví điện tử) — ví dụ tính tay
 ('2026-11-15 09:00', N'Tạo đơn hàng',                 NULL,             'CHO_THANH_TOAN', N'H=500,000; V=50,000; U=1000; F=20,000; T=370,000', 4, 'HeThong', NULL),
 ('2026-11-15 09:02', N'Xác nhận thanh toán',          'CHO_THANH_TOAN', 'CHO_XAC_NHAN', NULL, 4, 'HeThong',  NULL),
 ('2026-11-15 14:00', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 4, 'NhanVien', 'NV01'),
 ('2026-11-16 08:00', N'Bàn giao đơn vị vận chuyển',   'CHO_LAY_HANG',   'DANG_GIAO',    NULL, 4, 'NhanVien', 'NV02'),
 ('2026-11-18 15:00', N'Giao hàng thành công',         'DANG_GIAO',      'DA_GIAO',      NULL, 4, 'NhanVien', 'NV03'),
 -- Đơn 5 (COD, đang giao)
 ('2026-11-20 14:00', N'Tạo đơn hàng',                 NULL,             'CHO_XAC_NHAN', NULL, 5, 'HeThong',  NULL),
 ('2026-11-20 14:30', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 5, 'NhanVien', 'NV02'),
 ('2026-11-20 17:00', N'Bàn giao đơn vị vận chuyển',   'CHO_LAY_HANG',   'DANG_GIAO',    NULL, 5, 'NhanVien', 'NV03'),
 -- Đơn 6 (chuyển khoản, khách tự hủy khi chưa thanh toán)
 ('2026-11-21 21:00', N'Tạo đơn hàng',                 NULL,             'CHO_THANH_TOAN', NULL, 6, 'HeThong', NULL),
 ('2026-11-21 21:20', N'Hủy đơn hàng, hoàn tồn kho',   'CHO_THANH_TOAN', 'DA_HUY',       N'Khách đổi ý, muốn mua loại cáp 2m', 6, 'KhachHang', NULL),
 -- Đơn 7 (COD, chờ xác nhận)
 ('2026-11-22 10:00', N'Tạo đơn hàng',                 NULL,             'CHO_XAC_NHAN', NULL, 7, 'HeThong',  NULL),
 -- Đơn 8 (thẻ, chờ lấy hàng)
 ('2026-11-22 16:00', N'Tạo đơn hàng',                 NULL,             'CHO_THANH_TOAN', NULL, 8, 'HeThong', NULL),
 ('2026-11-22 16:01', N'Xác nhận thanh toán',          'CHO_THANH_TOAN', 'CHO_XAC_NHAN', NULL, 8, 'HeThong',  NULL),
 ('2026-11-22 20:00', N'Xác nhận đơn, chuẩn bị hàng',  'CHO_XAC_NHAN',   'CHO_LAY_HANG', NULL, 8, 'NhanVien', 'NV02');
GO

/* ---------- ĐÁNH GIÁ (chỉ dòng của đơn DA_GIAO, sau mốc giao — trigger T24 kiểm tra) ---------- */
INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, NoiDungBinhLuan, DanhGiaDungMoTa, SoLuotBamHuuIch, MaDonHang, SoThuTuDong) VALUES
 (5, '2026-02-10 20:00', N'Áo mặc mát, đúng size M, giao nhanh.',      N'Đúng với mô tả',                 3, 1, 1),
 (4, '2026-03-16 09:00', N'Giày êm nhưng hơi chật nửa size.',          N'Đúng với mô tả',                 1, 2, 1),
 (5, '2026-06-15 19:00', N'Giày đẹp, đóng gói cẩn thận.',              N'Đúng với mô tả',                 2, 3, 1),
 (3, '2026-06-15 19:05', N'Áo đẹp nhưng vải mỏng hơn mình nghĩ.',      N'Chất liệu khác mô tả một chút',  0, 3, 2),
 (5, '2026-11-19 08:00', N'Sạc nhanh, không bị nóng.',                 N'Đúng với mô tả',                 4, 4, 1),
 (4, '2026-11-19 08:03', N'Cáp chắc chắn, độ dài vừa đủ.',             NULL,                              0, 4, 2);

INSERT dbo.TEP_DANH_GIA (MaDanhGia, UriTep, LoaiTep) VALUES
 (1, '/review/1/anh-1.jpg',   'HinhAnh'),
 (1, '/review/1/video-1.mp4', 'Video'),
 (2, '/review/2/anh-1.jpg',   'HinhAnh'),
 (3, '/review/3/anh-1.jpg',   'HinhAnh'),
 (5, '/review/5/anh-1.jpg',   'HinhAnh'),
 (5, '/review/5/anh-2.jpg',   'HinhAnh');
GO

/* Đồng bộ thuộc tính dẫn xuất SAN_PHAM.TongSoLuongDaBan cho dữ liệu nạp trực tiếp.
   (Khi đã có trigger T25 của Hưng thì câu lệnh này không làm thay đổi giá trị.) */
UPDATE sp
SET TongSoLuongDaBan = ISNULL(x.SoLuong, 0)
FROM dbo.SAN_PHAM sp
LEFT JOIN (SELECT c.MaSanPham, SUM(c.SoLuongMua) AS SoLuong
           FROM dbo.CHI_TIET_DON_HANG c
           JOIN dbo.DON_HANG d ON d.MaDonHang = c.MaDonHang
           WHERE d.TrangThaiDon = 'DA_GIAO'
           GROUP BY c.MaSanPham) x ON x.MaSanPham = sp.MaSanPham;
GO
PRINT N'30: Đã nạp dữ liệu mẫu miền của Đại.';
GO
