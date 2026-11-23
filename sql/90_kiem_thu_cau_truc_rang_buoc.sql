/* =====================================================================
   90_kiem_thu_cau_truc_rang_buoc.sql — T14, T35 (Khưu Huỳnh Gia Hưng)
   Kiểm thử cấu trúc 22 bảng, ràng buộc một bảng của 10 bảng người dùng – sản phẩm,
   khóa ghép biến thể, NULL, và (nhóm V, M) ràng buộc liên bảng của file 15.

   CÁCH CHẠY: chạy cùng các file khác theo lệnh "Chạy toàn bộ" ở README.
   File chạy TRƯỚC 90_kiem_thu_don_hang_diem.sql nên KHÔNG được để lại thay đổi dữ liệu:
   mọi ca có sửa dữ liệu đều bọc trong BEGIN TRAN … ROLLBACK; ca K9 ở cuối kiểm lại số dòng.
   Ca kỳ vọng lỗi chỉ sai đúng một cột; các cột khác hợp lệ và chưa trùng (mã 9xx, kt.*@mail.vn).
   Mã 50399 dành riêng cho lỗi so sánh trong kiểm thử.
   ===================================================================== */
SET NOCOUNT ON;
GO
IF OBJECT_ID('tempdb..#KQ') IS NOT NULL DROP TABLE #KQ;
CREATE TABLE #KQ (STT INT IDENTITY(1,1), Ma VARCHAR(10), Dat BIT, MoTa NVARCHAR(200), ChiTiet NVARCHAR(2000));
GO
IF OBJECT_ID('tempdb..#Ghi') IS NOT NULL DROP PROCEDURE #Ghi;
GO
CREATE PROCEDURE #Ghi @Ma VARCHAR(10), @MoTa NVARCHAR(200), @Dat BIT, @ChiTiet NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT #KQ (Ma, Dat, MoTa, ChiTiet) VALUES (@Ma, ISNULL(@Dat, 0), @MoTa, @ChiTiet);
    PRINT CONCAT(CASE WHEN @Dat = 1 THEN N'PASS' ELSE N'FAIL' END, N' [', @Ma, N'] ', @MoTa, N' — ', @ChiTiet);
END;
GO
IF OBJECT_ID('tempdb..#KyVongLoi') IS NOT NULL DROP PROCEDURE #KyVongLoi;
GO
/* Chạy @Sql, kỳ vọng bị từ chối với mã lỗi @MaLoi */
CREATE PROCEDURE #KyVongLoi @Ma VARCHAR(10), @MoTa NVARCHAR(200), @MaLoi INT, @Sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @So INT = 0, @Msg NVARCHAR(2048) = N'Không bị từ chối (lẽ ra phải lỗi)', @Dat BIT;
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @So = ERROR_NUMBER(), @Msg = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
    SET @Dat = CASE WHEN @So = @MaLoi THEN 1 ELSE 0 END;
    IF @Dat = 0 SET @Msg = CONCAT(N'(kỳ vọng ', @MaLoi, N') ', @Msg);
    EXEC #Ghi @Ma, @MoTa, @Dat, @Msg;
END;
GO
IF OBJECT_ID('tempdb..#KyVongOK') IS NOT NULL DROP PROCEDURE #KyVongOK;
GO
/* Chạy @Sql, kỳ vọng thành công */
CREATE PROCEDURE #KyVongOK @Ma VARCHAR(10), @MoTa NVARCHAR(200), @Sql NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Dat BIT = 1, @Msg NVARCHAR(2048) = N'OK';
    BEGIN TRY
        EXEC sys.sp_executesql @Sql;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        SELECT @Dat = 0, @Msg = CONCAT(ERROR_NUMBER(), N': ', ERROR_MESSAGE());
    END CATCH;
    EXEC #Ghi @Ma, @MoTa, @Dat, @Msg;
END;
GO

/* =====================================================================
   K. CẤU TRÚC (T14)
   ===================================================================== */
DECLARE @n INT = (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped = 0);
DECLARE @d BIT = CASE WHEN @n = 22 THEN 1 ELSE 0 END, @ct NVARCHAR(2000) = CONCAT(N'Số bảng=', @n);
EXEC #Ghi 'K1', N'Đủ 22 bảng', @d, @ct;
GO
DECLARE @SoFK INT, @SoFKHaiCot INT, @d BIT, @ct NVARCHAR(2000);
SELECT @SoFK = COUNT(*), @SoFKHaiCot = SUM(CASE WHEN SoCot = 2 THEN 1 ELSE 0 END)
FROM (SELECT fk.object_id, COUNT(*) AS SoCot
      FROM sys.foreign_keys fk
      JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
      WHERE fk.referenced_object_id = OBJECT_ID('dbo.BIEN_THE_SAN_PHAM')
      GROUP BY fk.object_id) x;
SELECT @d = CASE WHEN @SoFK = 2 AND @SoFKHaiCot = 2 THEN 1 ELSE 0 END,
       @ct = CONCAT(N'Số FK=', @SoFK, N'; số FK 2 cột=', @SoFKHaiCot);
EXEC #Ghi 'K2', N'Biến thể được tham chiếu bằng đúng 2 khóa ngoại ghép (GIO_HANG, CHI_TIET_DON_HANG)', @d, @ct;
GO
DECLARE @ct NVARCHAR(2000), @n INT, @d BIT;
SELECT @n = COUNT(*), @ct = STRING_AGG(t.name, ', ')
FROM sys.tables t
WHERE t.is_ms_shipped = 0
  AND NOT EXISTS (SELECT 1 FROM sys.key_constraints k WHERE k.parent_object_id = t.object_id AND k.type = 'PK');
SELECT @d = CASE WHEN @n = 0 THEN 1 ELSE 0 END, @ct = CONCAT(N'Bảng thiếu PK: ', @n, N' ', @ct);
EXEC #Ghi 'K3', N'Mọi bảng đều có khóa chính', @d, @ct;
GO
DECLARE @ct NVARCHAR(2000), @Thieu INT, @d BIT;
WITH Dem (Bang, SoDong) AS (
    SELECT 'NGUOI_DUNG',        COUNT(*) FROM dbo.NGUOI_DUNG        UNION ALL
    SELECT 'SDT_LIEN_LAC',      COUNT(*) FROM dbo.SDT_LIEN_LAC      UNION ALL
    SELECT 'KHACH_HANG',        COUNT(*) FROM dbo.KHACH_HANG        UNION ALL
    SELECT 'NHAN_VIEN',         COUNT(*) FROM dbo.NHAN_VIEN         UNION ALL
    SELECT 'DIA_CHI',           COUNT(*) FROM dbo.DIA_CHI           UNION ALL
    SELECT 'DANH_MUC',          COUNT(*) FROM dbo.DANH_MUC          UNION ALL
    SELECT 'THUONG_HIEU',       COUNT(*) FROM dbo.THUONG_HIEU       UNION ALL
    SELECT 'SAN_PHAM',          COUNT(*) FROM dbo.SAN_PHAM          UNION ALL
    SELECT 'HINH_ANH_SAN_PHAM', COUNT(*) FROM dbo.HINH_ANH_SAN_PHAM UNION ALL
    SELECT 'BIEN_THE_SAN_PHAM', COUNT(*) FROM dbo.BIEN_THE_SAN_PHAM)
SELECT @Thieu = SUM(CASE WHEN SoDong < 5 THEN 1 ELSE 0 END),
       @ct = STRING_AGG(CONCAT(Bang, '=', SoDong), ', ')
FROM Dem;
SET @d = CASE WHEN @Thieu = 0 THEN 1 ELSE 0 END;
EXEC #Ghi 'K4', N'Mỗi bảng trong 10 bảng người dùng – sản phẩm có ít nhất 5 dòng', @d, @ct;
GO
DECLARE @Ten TABLE (Ten SYSNAME PRIMARY KEY);
INSERT @Ten (Ten) VALUES
 ('PK_NGUOI_DUNG'), ('UQ_NGUOI_DUNG_TenDangNhap'), ('UQ_NGUOI_DUNG_Email'), ('CK_NGUOI_DUNG_Email'),
 ('CK_NGUOI_DUNG_GioiTinh'), ('CK_NGUOI_DUNG_NgaySinh'), ('CK_NGUOI_DUNG_SdtXacThuc'),
 ('PK_SDT_LIEN_LAC'), ('FK_SDT_LIEN_LAC_NGUOI_DUNG'), ('CK_SDT_LIEN_LAC_So'),
 ('PK_KHACH_HANG'), ('FK_KHACH_HANG_NGUOI_DUNG'),
 ('PK_NHAN_VIEN'), ('UQ_NHAN_VIEN_MaNhanVien'), ('FK_NHAN_VIEN_NGUOI_DUNG'), ('CK_NHAN_VIEN_Luong'), ('CK_NHAN_VIEN_NgayVaoLam'),
 ('PK_DIA_CHI'), ('UQ_DIA_CHI_MaDiaChi_MaKhachHang'), ('FK_DIA_CHI_KHACH_HANG'), ('CK_DIA_CHI_Sdt'),
 ('DF_DIA_CHI_LaMacDinh'), ('DF_DIA_CHI_LayHang'), ('DF_DIA_CHI_TraHang'),
 ('PK_DANH_MUC'), ('FK_DANH_MUC_CHA'), ('CK_DANH_MUC_KhongTuTroCha'), ('UQ_DANH_MUC_TenTrongCha'),
 ('PK_THUONG_HIEU'), ('UQ_THUONG_HIEU_Ten'),
 ('PK_SAN_PHAM'), ('FK_SAN_PHAM_THUONG_HIEU'), ('FK_SAN_PHAM_DANH_MUC'), ('CK_SAN_PHAM_GiaNiemYet'), ('CK_SAN_PHAM_DaBan'), ('DF_SAN_PHAM_DaBan'),
 ('PK_HINH_ANH_SAN_PHAM'), ('FK_HINH_ANH_SAN_PHAM'),
 ('PK_BIEN_THE_SAN_PHAM'), ('FK_BIEN_THE_SAN_PHAM'), ('UQ_BIEN_THE_PhanLoai'), ('CK_BIEN_THE_TonKho'), ('CK_BIEN_THE_Gia'),
 ('CK_BIEN_THE_MaDinhDang'), ('DF_BIEN_THE_TonKho');
DECLARE @CoMat INT, @Thieu NVARCHAR(2000), @Index INT, @TongTen INT = (SELECT COUNT(*) FROM @Ten);
SELECT @CoMat = COUNT(*) FROM @Ten t WHERE OBJECT_ID(N'dbo.' + t.Ten) IS NOT NULL;
SELECT @Thieu = STRING_AGG(t.Ten, ', ') FROM @Ten t WHERE OBJECT_ID(N'dbo.' + t.Ten) IS NULL;
SELECT @Index = COUNT(*) FROM sys.indexes
WHERE name = 'UX_DIA_CHI_MotMacDinh' AND object_id = OBJECT_ID('dbo.DIA_CHI') AND is_unique = 1 AND has_filter = 1;
DECLARE @d BIT = CASE WHEN @TongTen = 45 AND @CoMat = 45 AND @Index = 1 THEN 1 ELSE 0 END,
        @ct NVARCHAR(2000) = CONCAT(N'Có ', @CoMat, N'/', @TongTen, N'; index lọc=', @Index, N'; thiếu: ', @Thieu);
EXEC #Ghi 'K5', N'Đủ 45 ràng buộc có tên và index lọc UX_DIA_CHI_MotMacDinh', @d, @ct;
GO
DECLARE @c NVARCHAR(128) = CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS NVARCHAR(128));
DECLARE @d BIT = CASE WHEN @c = N'SQL_Latin1_General_CP1_CI_AS' THEN 1 ELSE 0 END;
EXEC #Ghi 'K6', N'Collation của DB là SQL_Latin1_General_CP1_CI_AS', @d, @c;
GO
DECLARE @n INT, @ct NVARCHAR(2000), @d BIT;
SELECT @n = COUNT(*), @ct = STRING_AGG(CONCAT(OBJECT_NAME(c.object_id), '.', c.name), ', ')
FROM sys.columns c
WHERE c.is_nullable = 1
  AND c.object_id IN (OBJECT_ID('dbo.NGUOI_DUNG'), OBJECT_ID('dbo.SDT_LIEN_LAC'), OBJECT_ID('dbo.KHACH_HANG'),
                      OBJECT_ID('dbo.NHAN_VIEN'), OBJECT_ID('dbo.DIA_CHI'), OBJECT_ID('dbo.DANH_MUC'),
                      OBJECT_ID('dbo.THUONG_HIEU'), OBJECT_ID('dbo.SAN_PHAM'), OBJECT_ID('dbo.HINH_ANH_SAN_PHAM'),
                      OBJECT_ID('dbo.BIEN_THE_SAN_PHAM'));
SELECT @d = CASE WHEN @n = 6 THEN 1 ELSE 0 END, @ct = CONCAT(@n, N': ', @ct);
EXEC #Ghi 'K7', N'Đúng 6 cột cho phép NULL (khớp data dictionary)', @d, @ct;
GO
DECLARE @q INT = CAST(SESSIONPROPERTY('QUOTED_IDENTIFIER') AS INT);
DECLARE @d BIT = CASE WHEN @q = 1 THEN 1 ELSE 0 END, @ct NVARCHAR(20) = CONCAT(@q, N'');
EXEC #Ghi 'K8', N'Phiên chạy có QUOTED_IDENTIFIER ON (sqlcmd có cờ -I)', @d, @ct;
GO

/* =====================================================================
   N. RÀNG BUỘC MỘT BẢNG: NGƯỜI DÙNG, NHÂN VIÊN, NULL (T11, T35)
   ===================================================================== */
EXEC #KyVongLoi 'N1', N'Trùng tên đăng nhập', 2627, N'BEGIN TRAN;
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email)
VALUES (901, ''an.nguyen'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.n1@mail.vn'');
ROLLBACK;';
EXEC #KyVongLoi 'N2', N'Email sai định dạng', 547, N'BEGIN TRAN;
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email)
VALUES (902, ''kt.n2'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''abc'');
ROLLBACK;';
EXEC #KyVongLoi 'N3', N'Ngày sinh ở tương lai (ngày mai giờ VN)', 547, N'BEGIN TRAN;
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email, NgaySinh)
VALUES (903, ''kt.n3'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.n3@mail.vn'', DATEADD(DAY, 1, CAST(dbo.fn_ThoiDiemVN() AS DATE)));
ROLLBACK;';
EXEC #KyVongLoi 'N4', N'Giới tính ngoài Nam/Nữ/Khác', 547, N'BEGIN TRAN;
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email, GioiTinh)
VALUES (904, ''kt.n4'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.n4@mail.vn'', N''Không rõ'');
ROLLBACK;';
EXEC #KyVongLoi 'N5', N'Lương nhân viên bằng 0', 547, N'BEGIN TRAN;
INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam) VALUES (1, ''NV80'', N''Thử việc'', 0, ''2025-01-01'');
ROLLBACK;';
EXEC #KyVongLoi 'N6', N'Ngày vào làm ở tương lai (ngày mai giờ VN)', 547, N'BEGIN TRAN;
INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam)
VALUES (1, ''NV81'', N''Thử việc'', 1000000, DATEADD(DAY, 1, CAST(dbo.fn_ThoiDiemVN() AS DATE)));
ROLLBACK;';
EXEC #KyVongLoi 'N7', N'Trùng mã nhân viên NV01', 2627, N'BEGIN TRAN;
INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam) VALUES (1, ''NV01'', N''Thử việc'', 1000000, ''2025-01-01'');
ROLLBACK;';
EXEC #KyVongLoi 'N8', N'NULL vào cột bắt buộc (tên thương hiệu)', 515, N'BEGIN TRAN;
INSERT dbo.THUONG_HIEU (MaThuongHieu, TenThuongHieu) VALUES (90, NULL);
ROLLBACK;';
GO

/* =====================================================================
   KG. KHÓA GHÉP BIẾN THỂ (T04)
   ===================================================================== */
EXEC #KyVongLoi 'KG1', N'Giỏ hàng ghép sản phẩm 2 với mã DEN-M của sản phẩm 1', 547, N'BEGIN TRAN;
INSERT dbo.GIO_HANG (MaKhachHang, MaSanPham, MaBienTheNoiBo, SoLuongDuMua) VALUES (6, 2, ''DEN-M'', 1);
ROLLBACK;';
GO

/* =====================================================================
   DC. ĐỊA CHỈ (RB13, RB14)
   ===================================================================== */
EXEC #KyVongLoi 'DC1', N'SĐT người nhận không đủ 10 chữ số', 547, N'BEGIN TRAN;
INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho)
VALUES (91, 6, N''Kiểm Thử'', ''12345'', N''1'', N''Đường Thử'', N''Phường Thử'', N''TP. Thử'');
ROLLBACK;';
EXEC #KyVongLoi 'DC2', N'Khách 1 có địa chỉ mặc định thứ hai', 2601, N'BEGIN TRAN;
INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho, LaMacDinh)
VALUES (92, 1, N''Kiểm Thử'', ''0909000092'', N''2'', N''Đường Thử'', N''Phường Thử'', N''TP. Thử'', 1);
ROLLBACK;';
EXEC #KyVongLoi 'DC3', N'Địa chỉ của người dùng 5 (chỉ là nhân viên)', 547, N'BEGIN TRAN;
INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho)
VALUES (93, 5, N''Kiểm Thử'', ''0909000093'', N''3'', N''Đường Thử'', N''Phường Thử'', N''TP. Thử'');
ROLLBACK;';
EXEC #KyVongOK 'DC4', N'Địa chỉ dài tối đa vẫn đặt được đơn (chuỗi ghép 325 ký tự ≤ 400)', N'BEGIN TRAN;
INSERT dbo.DIA_CHI (MaDiaChi, MaKhachHang, TenNguoiNhan, SdtNguoiNhan, SoNha, TenDuong, Phuong, TinhThanhPho)
VALUES (99, 6, REPLICATE(N''N'', 100), ''0909999999'', REPLICATE(N''S'', 20), REPLICATE(N''Đ'', 100), REPLICATE(N''P'', 100), REPLICATE(N''T'', 100));
DECLARE @id INT;
EXEC dbo.sp_TaoDonHang 6, 99, 2, 1, N''[{"MaSanPham":6,"MaBienTheNoiBo":"TRONG-IP15","SoLuong":1}]'', @MaDonHang = @id OUTPUT;
IF NOT EXISTS (SELECT 1 FROM dbo.DON_HANG WHERE MaDonHang = @id AND LEN(DiaChiGiaoHang) = 325 AND SdtNguoiNhan = ''0909999999'')
    THROW 50399, N''Đơn không chép đúng địa chỉ dài 325 ký tự hoặc SĐT.'', 1;
ROLLBACK;';
GO

/* =====================================================================
   M1, SP, BT. DANH MỤC, SẢN PHẨM, BIẾN THỂ (T12)
   ===================================================================== */
EXEC #KyVongLoi 'M1', N'Danh mục tự làm cha của chính nó', 547, N'BEGIN TRAN;
UPDATE dbo.DANH_MUC SET MaDanhMucCha = MaDanhMuc WHERE MaDanhMuc = 1;
ROLLBACK;';
EXEC #KyVongLoi 'SP1', N'Giá niêm yết bằng 0', 547, N'BEGIN TRAN;
INSERT dbo.SAN_PHAM (MaSanPham, TenSanPham, GiaNiemYet, MaThuongHieu, MaDanhMuc) VALUES (91, N''Sản phẩm thử'', 0, 1, 2);
ROLLBACK;';
EXEC #KyVongLoi 'BT1', N'Mã biến thể có chữ thường', 547, N'BEGIN TRAN;
INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES (1, ''den-xl'', N''Đen'', N''XL'', 5, 199000);
ROLLBACK;';
EXEC #KyVongLoi 'BT2', N'Tồn kho âm', 547, N'BEGIN TRAN;
INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES (1, ''DEN-XL'', N''Đen'', N''XL'', -1, 199000);
ROLLBACK;';
EXEC #KyVongLoi 'BT3', N'Trùng khóa (1, DEN-M), màu/cỡ khác', 2627, N'BEGIN TRAN;
INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES (1, ''DEN-M'', N''Tím'', N''S'', 5, 199000);
ROLLBACK;';
EXEC #KyVongLoi 'BT4', N'Trùng phân loại chỉ khác hoa/thường (đen – Đen, cỡ M)', 2627, N'BEGIN TRAN;
INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES (1, ''DEN-M3'', N''đen'', N''M'', 5, 199000);
ROLLBACK;';
EXEC #KyVongOK 'BT5', N'Khác dấu là khác màu (Den – Đen, cỡ M)', N'BEGIN TRAN;
INSERT dbo.BIEN_THE_SAN_PHAM (MaSanPham, MaBienTheNoiBo, MauSac, KichCo, TonKhoRieng, GiaBanRieng) VALUES (1, ''DEN-M4'', N''Den'', N''M'', 5, 199000);
ROLLBACK;';
GO

/* =====================================================================
   V. TOTAL SPECIALIZATION VÀ TUỔI KHÁCH HÀNG (T15: sp_TaoNguoiDung + trigger, RB4)
   H = ngày VN hôm nay. Mọi ca bọc trong BEGIN TRAN … ROLLBACK.
   ===================================================================== */
EXEC #KyVongLoi 'V1', N'Tạo người dùng không có vai trò nào', 50222, N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 911, ''kt.v1'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v1@mail.vn'', NULL, NULL, ''2000-01-01'', 0;
ROLLBACK;';
EXEC #KyVongLoi 'V2', N'INSERT thẳng vào NGUOI_DUNG, không qua sp_TaoNguoiDung', 50223, N'BEGIN TRAN;
INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email) VALUES (901, ''kt.v2'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v2@mail.vn'');
ROLLBACK;';
EXEC #KyVongOK 'V3', N'Tạo người dùng vừa là khách vừa là nhân viên (overlapping)', N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 902, ''kt.v3'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v3@mail.vn'', NULL, N''Nữ'', ''2000-01-01'', 1,
     @MaNhanVien = ''NV90'', @ChucVu = N''Nhân viên thử'', @Luong = 8000000, @NgayVaoLam = ''2025-01-01'';
IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaNguoiDung = 902) OR NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN WHERE MaNguoiDung = 902)
    THROW 50399, N''Người dùng 902 thiếu một trong hai vai trò.'', 1;
ROLLBACK;';
EXEC #KyVongLoi 'V4', N'Xóa vai trò cuối cùng (khách) của người dùng còn tồn tại', 50224, N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 903, ''kt.v4'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v4@mail.vn'', NULL, NULL, ''2000-01-01'', 1;
DELETE dbo.KHACH_HANG WHERE MaNguoiDung = 903;
ROLLBACK;';
EXEC #KyVongOK 'V5', N'Xóa vai trò nhân viên khi vẫn còn vai trò khách', N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 904, ''kt.v5'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v5@mail.vn'', NULL, NULL, ''2000-01-01'', 1,
     @MaNhanVien = ''NV91'', @ChucVu = N''Nhân viên thử'', @Luong = 8000000, @NgayVaoLam = ''2025-01-01'';
DELETE dbo.NHAN_VIEN WHERE MaNguoiDung = 904;
IF NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaNguoiDung = 904) THROW 50399, N''Người dùng 904 mất luôn vai trò khách.'', 1;
ROLLBACK;';
EXEC #KyVongOK 'V6', N'Xóa hẳn người dùng thì vai trò bị xóa theo (CASCADE)', N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 905, ''kt.v6'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v6@mail.vn'', NULL, NULL, ''2000-01-01'', 1;
DELETE dbo.NGUOI_DUNG WHERE MaNguoiDung = 905;
IF EXISTS (SELECT 1 FROM dbo.KHACH_HANG WHERE MaNguoiDung = 905) THROW 50399, N''Còn dòng KHACH_HANG của người dùng đã xóa.'', 1;
ROLLBACK;';
EXEC #KyVongLoi 'V7', N'Khách còn thiếu một ngày mới đủ 13 tuổi', 50220, N'BEGIN TRAN;
DECLARE @H DATE = CAST(dbo.fn_ThoiDiemVN() AS DATE);
DECLARE @NS DATE = DATEADD(DAY, 1, DATEADD(YEAR, -13, @H));
EXEC dbo.sp_TaoNguoiDung 906, ''kt.v7'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v7@mail.vn'', NULL, NULL, @NS, 1;
ROLLBACK;';
EXEC #KyVongOK 'V10', N'Khách tròn 13 tuổi hôm nay được tạo', N'BEGIN TRAN;
DECLARE @H DATE = CAST(dbo.fn_ThoiDiemVN() AS DATE);
DECLARE @NS DATE = DATEADD(YEAR, -13, @H);
EXEC dbo.sp_TaoNguoiDung 907, ''kt.v10'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v10@mail.vn'', NULL, NULL, @NS, 1;
ROLLBACK;';
EXEC #KyVongLoi 'V11', N'Có mã nhân viên nhưng thiếu lương', 50225, N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 908, ''kt.v11'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v11@mail.vn'', NULL, NULL, ''2000-01-01'', 0,
     @MaNhanVien = ''NV92'', @ChucVu = N''Nhân viên thử'', @Luong = NULL, @NgayVaoLam = ''2025-01-01'';
ROLLBACK;';
EXEC #KyVongLoi 'V12', N'Khách hàng không có ngày sinh', 50220, N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 909, ''kt.v12'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v12@mail.vn'', NULL, NULL, NULL, 1;
ROLLBACK;';
EXEC #KyVongLoi 'V8', N'Sửa ngày sinh làm khách 1 còn 10 tuổi', 50221, N'BEGIN TRAN;
UPDATE dbo.NGUOI_DUNG SET NgaySinh = DATEADD(YEAR, -10, CAST(dbo.fn_ThoiDiemVN() AS DATE)) WHERE MaNguoiDung = 1;
ROLLBACK;';
EXEC #KyVongOK 'V9', N'Nhân viên NV02 (sinh 1998) thêm vai trò khách', N'BEGIN TRAN;
INSERT dbo.KHACH_HANG (MaNguoiDung) VALUES (5);
ROLLBACK;';
EXEC #KyVongLoi 'V13', N'Chuyển vai trò khách cuối cùng sang người khác (UPDATE MaNguoiDung)', 50224, N'BEGIN TRAN;
EXEC dbo.sp_TaoNguoiDung 910, ''kt.v13'', ''sha256$kt'', N''Kiểm'', N''Thử'', ''kt.v13@mail.vn'', NULL, NULL, ''2000-01-01'', 1;
UPDATE dbo.KHACH_HANG SET MaNguoiDung = 5 WHERE MaNguoiDung = 910;
ROLLBACK;';
GO

/* =====================================================================
   M. CÂY DANH MỤC KHÔNG CÓ VÒNG (RB9, trigger trg_DanhMuc_KhongVongLap)
   Danh mục mẫu: 1 Thời trang (gốc) > 2 Áo, 3 Giày dép; 4 Điện tử (gốc) > 5 Phụ kiện điện thoại.
   ===================================================================== */
EXEC #KyVongLoi 'M2', N'Vòng hai cấp: đặt cha của 1 là con 2 của nó', 50240, N'BEGIN TRAN;
UPDATE dbo.DANH_MUC SET MaDanhMucCha = 2 WHERE MaDanhMuc = 1;
ROLLBACK;';
EXEC #KyVongLoi 'M3', N'Một câu lệnh sửa nhiều dòng tạo vòng 4 ↔ 5', 50240, N'BEGIN TRAN;
UPDATE dbo.DANH_MUC SET MaDanhMucCha = CASE MaDanhMuc WHEN 4 THEN 5 ELSE 4 END WHERE MaDanhMuc IN (4, 5);
ROLLBACK;';
EXEC #KyVongOK 'M4', N'Chuyển danh mục 3 sang dưới danh mục 2 (không tạo vòng)', N'BEGIN TRAN;
UPDATE dbo.DANH_MUC SET MaDanhMucCha = 2 WHERE MaDanhMuc = 3;
ROLLBACK;';
EXEC #KyVongOK 'M5', N'Thêm danh mục con mới dưới danh mục 2', N'BEGIN TRAN;
INSERT dbo.DANH_MUC (MaDanhMuc, TenDanhMuc, MaDanhMucCha) VALUES (90, N''Áo khoác'', 2);
ROLLBACK;';
GO

/* =====================================================================
   K9. ĐẶT CUỐI FILE: file này không để lại thay đổi dữ liệu
   ===================================================================== */
DECLARE @nd INT = (SELECT COUNT(*) FROM dbo.NGUOI_DUNG),
        @dc INT = (SELECT COUNT(*) FROM dbo.DIA_CHI),
        @bt INT = (SELECT COUNT(*) FROM dbo.BIEN_THE_SAN_PHAM),
        @dm INT = (SELECT COUNT(*) FROM dbo.DANH_MUC WHERE MaDanhMuc = MaDanhMucCha);
DECLARE @d BIT = CASE WHEN @nd = 9 AND @dc = 6 AND @bt = 10 AND @dm = 0 THEN 1 ELSE 0 END,
        @ct NVARCHAR(2000) = CONCAT(N'NGUOI_DUNG=', @nd, N', DIA_CHI=', @dc, N', BIEN_THE=', @bt, N', danh mục tự trỏ=', @dm);
EXEC #Ghi 'K9', N'Số dòng sau kiểm thử: 9 người dùng, 6 địa chỉ, 10 biến thể; không danh mục nào tự trỏ', @d, @ct;
GO

/* ---------- TỔNG HỢP ---------- */
SELECT COUNT(*) AS TongSoCa, SUM(CAST(Dat AS INT)) AS SoPass, COUNT(*) - SUM(CAST(Dat AS INT)) AS SoFail FROM #KQ;
SELECT Ma, MoTa, ChiTiet FROM #KQ WHERE Dat = 0 ORDER BY STT;
GO
