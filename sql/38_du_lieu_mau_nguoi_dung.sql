/* =====================================================================
   38_du_lieu_mau_nguoi_dung.sql — dữ liệu mẫu miền người dùng (Khưu Huỳnh Gia Hưng)
   NGUOI_DUNG, SDT_LIEN_LAC, KHACH_HANG, NHAN_VIEN, DIA_CHI.
   Giữ nguyên mã của file tạm 00 cũ vì 40_du_lieu_mau_don_hang_diem.sql dựa vào chúng:
     người dùng 1–7; khách 1, 2, 3, 4, 6; NV01 = người dùng 4 (vừa là khách vừa là nhân viên),
     NV02 = 5, NV03 = 7; địa chỉ 1–6.
   Thêm người dùng 8 (NV04), 9 (NV05) để NHAN_VIEN có đủ 5 dòng.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email, SdtXacThuc, GioiTinh, NgaySinh) VALUES
 (1, 'an.nguyen',   'sha256$a1', N'Nguyễn Văn', N'An',    'an.nguyen@mail.vn',   '0901000001', N'Nam', '2002-03-15'),
 (2, 'binh.tran',   'sha256$a2', N'Trần Thị',   N'Bình',  'binh.tran@mail.vn',   '0901000002', N'Nữ',  '1999-07-20'),
 (3, 'chi.le',      'sha256$a3', N'Lê Minh',    N'Chi',   'chi.le@mail.vn',      '0901000003', N'Nữ',  '2004-11-02'),
 (4, 'dung.pham',   'sha256$a4', N'Phạm Quốc',  N'Dũng',  'dung.pham@mail.vn',   '0901000004', N'Nam', '1995-01-30'),
 (5, 'em.hoang',    'sha256$a5', N'Hoàng Thu',  N'Em',    'em.hoang@mail.vn',    '0901000005', N'Nữ',  '1998-05-12'),
 (6, 'giang.vo',    'sha256$a6', N'Võ Trường',  N'Giang', 'giang.vo@mail.vn',    '0901000006', N'Nam', '2001-09-09'),
 (7, 'hai.dang',    'sha256$a7', N'Đặng Thanh', N'Hải',   'hai.dang@mail.vn',    '0901000007', N'Nam', '1993-12-25'),
 (8, 'khoa.bui',    'sha256$a8', N'Bùi Đăng',   N'Khoa',  'khoa.bui@mail.vn',    '0901000008', N'Nam', '1997-04-18'),
 (9, 'lan.ngo',     'sha256$a9', N'Ngô Ngọc',   N'Lan',   'lan.ngo@mail.vn',     '0901000009', N'Nữ',  '2000-10-05');

INSERT dbo.SDT_LIEN_LAC (MaNguoiDung, SoDienThoai) VALUES
 (1,'0911000001'),(2,'0911000002'),(3,'0911000003'),(4,'0911000004'),(6,'0911000006');

-- Khách hàng: 1, 2, 3, 4, 6.  Nhân viên: 4 (NV01), 5 (NV02), 7 (NV03), 8 (NV04), 9 (NV05)
INSERT dbo.KHACH_HANG (MaNguoiDung) VALUES (1),(2),(3),(4),(6);
INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam) VALUES
 (4, 'NV01', N'Nhân viên xử lý đơn',           12000000, '2024-03-01'),
 (5, 'NV02', N'Nhân viên kho',                 10000000, '2024-06-15'),
 (7, 'NV03', N'Trưởng nhóm vận hành',          18000000, '2023-09-01'),
 (8, 'NV04', N'Nhân viên chăm sóc khách hàng',  9500000, '2025-02-10'),
 (9, 'NV05', N'Nhân viên kho',                  9000000, '2025-08-01');

INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho, LaMacDinh) VALUES
 (1, 1, N'Nguyễn Văn An',      '0901000001', N'268',   N'Lý Thường Kiệt', N'Phường Diên Hồng', N'TP. Hồ Chí Minh', 1),
 (2, 2, N'Trần Thị Bình',      '0901000002', N'12A',   N'Nguyễn Trãi',    N'Phường Bến Thành', N'TP. Hồ Chí Minh', 1),
 (3, 3, N'Lê Minh Chi',        '0901000003', N'45',    N'Trần Phú',       N'Phường Hải Châu',  N'TP. Đà Nẵng',     1),
 (4, 4, N'Phạm Quốc Dũng',     '0901000004', N'7',     N'Hai Bà Trưng',   N'Phường Hoàn Kiếm', N'TP. Hà Nội',      1),
 (5, 6, N'Võ Trường Giang',    '0901000006', N'101',   N'Võ Văn Ngân',    N'Phường Thủ Đức',   N'TP. Hồ Chí Minh', 1),
 (6, 1, N'Nguyễn Văn An (KTX)','0901000001', N'KTX B', N'Tô Vĩnh Diện',   N'Phường Linh Xuân', N'TP. Hồ Chí Minh', 0);
GO
PRINT N'38: Đã nạp 9 người dùng, 5 khách hàng, 5 nhân viên, 6 địa chỉ.';
GO
