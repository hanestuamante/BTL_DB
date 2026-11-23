/* =====================================================================
   39_du_lieu_mau_san_pham.sql — dữ liệu mẫu miền sản phẩm
   Miền dữ liệu của Lê Viễn Bằng (T16). Bản hiện tại do Khưu Huỳnh Gia Hưng chuyển nguyên
   từ file tạm 00 cũ khi bỏ file đó; Bằng mở rộng ở T16.
   DANH_MUC, THUONG_HIEU, SAN_PHAM, HINH_ANH_SAN_PHAM, BIEN_THE_SAN_PHAM.
   Giữ nguyên mã sản phẩm 1–6 và 10 biến thể vì 40_du_lieu_mau_don_hang_diem.sql dựa vào chúng.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

INSERT dbo.DANH_MUC (MaDanhMuc, TenDanhMuc, MaDanhMucCha) VALUES
 (1, N'Thời trang', NULL), (2, N'Áo', 1), (3, N'Giày dép', 1), (4, N'Điện tử', NULL), (5, N'Phụ kiện điện thoại', 4);

INSERT dbo.THUONG_HIEU (MaThuongHieu, TenThuongHieu) VALUES
 (1, N'Coolmate'), (2, N'Biti''s'), (3, N'Anker'), (4, N'Uniqlo'), (5, N'Baseus');

INSERT dbo.SAN_PHAM (MaSanPham, TenSanPham, GiaNiemYet, MoTaChiTiet, MaThuongHieu, MaDanhMuc) VALUES
 (1, N'Áo thun cotton nam',          199000, N'Cotton 100%, form regular', 1, 2),
 (2, N'Giày thể thao Hunter',        899000, N'Đế cao su, thoáng khí',     2, 3),
 (3, N'Củ sạc nhanh 20W',            350000, N'Chuẩn PD 20W',              3, 5),
 (4, N'Áo khoác gió chống nước',     590000, N'Vải dù 2 lớp',              4, 2),
 (5, N'Cáp sạc USB-C',               120000, N'Bện dù, sạc nhanh 60W',     5, 5),
 (6, N'Ốp lưng điện thoại trong suốt', 80000, N'TPU chống ố vàng',         5, 5);

INSERT dbo.HINH_ANH_SAN_PHAM (MaSanPham, DuongDanHinhAnh) VALUES
 (1,'/img/sp1-1.jpg'),(2,'/img/sp2-1.jpg'),(3,'/img/sp3-1.jpg'),(4,'/img/sp4-1.jpg'),(5,'/img/sp5-1.jpg'),(6,'/img/sp6-1.jpg');

INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES
 (1, 'DEN-M',     N'Đen',       N'M',    50, 199000),
 (1, 'DEN-L',     N'Đen',       N'L',    40, 199000),
 (1, 'TRANG-M',   N'Trắng',     N'M',    30, 189000),
 (2, 'XAM-40',    N'Xám',       N'40',   20, 899000),
 (2, 'XAM-41',    N'Xám',       N'41',   15, 899000),
 (3, 'TRANG-20W', N'Trắng',     N'20W', 100, 350000),
 (4, 'XANH-L',    N'Xanh navy', N'L',    25, 590000),
 (5, 'DEN-1M',    N'Đen',       N'1m',   80, 120000),
 (5, 'DEN-2M',    N'Đen',       N'2m',   60, 150000),
 (6, 'TRONG-IP15',N'Trong suốt',N'iPhone 15', 70, 80000);
GO
PRINT N'39: Đã nạp 5 danh mục, 5 thương hiệu, 6 sản phẩm, 6 hình ảnh, 10 biến thể.';
GO
