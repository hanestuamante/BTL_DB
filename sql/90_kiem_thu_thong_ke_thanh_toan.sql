/* =====================================================================
   90_kiem_thu_thong_ke_thanh_toan.sql — T40, T16 (Lê Viễn Bằng)
   Đối chiếu F2, Q2 và độ phủ dữ liệu mẫu. Chạy sau kiểm thử đơn hàng – điểm.
   Ca đơn rỗng ROLLBACK dữ liệu, nhưng SQL Server vẫn cấp một số IDENTITY.
   Có ca FAIL thì THROW 50599.
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

DROP TABLE IF EXISTS #KQ;
CREATE TABLE #KQ (STT INT IDENTITY(1,1), Ma VARCHAR(10), Dat BIT, MoTa NVARCHAR(200), ChiTiet NVARCHAR(2000));
GO
DROP PROCEDURE IF EXISTS #Ghi;
GO
CREATE PROCEDURE #Ghi @Ma VARCHAR(10), @MoTa NVARCHAR(200), @Dat BIT, @ChiTiet NVARCHAR(2000)
AS
BEGIN
    SET NOCOUNT ON;
    INSERT #KQ (Ma, Dat, MoTa, ChiTiet) VALUES (@Ma, ISNULL(@Dat, 0), @MoTa, @ChiTiet);
    PRINT CONCAT(CASE WHEN @Dat = 1 THEN N'PASS' ELSE N'FAIL' END, N' [', @Ma, N'] ', @MoTa, N' — ', @ChiTiet);
END;
GO

/* F2: số cố định cho các đơn mẫu 1–5 và các mã lỗi. */
INSERT #KQ (Ma, Dat, MoTa, ChiTiet)
SELECT ca.Ma, CASE WHEN tinh.ThucTe = ca.KyVong THEN 1 ELSE 0 END,
       ca.MoTa, CONCAT(N'Kỳ vọng: ', ca.KyVong, N', thực tế: ', COALESCE(CONVERT(VARCHAR(24), tinh.ThucTe), 'NULL'))
FROM (VALUES
    ('F01', 1, 403000, N'Tổng thanh toán đơn 1'),
    ('F02', 2, 914000, N'Tổng thanh toán đơn 2'),
    ('F03', 3, 1312000, N'Tổng thanh toán đơn 3'),
    ('F04', 4, 370000, N'Tổng thanh toán đơn 4'),
    ('F05', 5, 585000, N'Tổng thanh toán đơn 5'),
    ('F06', NULL, -1, N'Mã đơn NULL'),
    ('F07', 0, -1, N'Mã đơn 0'),
    ('F08', -5, -1, N'Mã đơn âm'),
    ('F09', 2147483647, -2, N'Đơn không tồn tại')
) AS ca(Ma, MaDonHang, KyVong, MoTa)
CROSS APPLY (VALUES (dbo.fn_TinhTongThanhToan(ca.MaDonHang))) AS tinh(ThucTe);

DECLARE @Dat BIT, @ChiTiet NVARCHAR(2000);
SELECT @ChiTiet = STRING_AGG(CONVERT(NVARCHAR(MAX), v.MaDonHang), N', ')
FROM dbo.vw_TienDonHang AS v
CROSS APPLY (VALUES (dbo.fn_TinhTongThanhToan(v.MaDonHang))) AS tinh(ThucTe)
WHERE EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG AS ct WHERE ct.MaDonHang = v.MaDonHang)
  AND (tinh.ThucTe IS NULL OR tinh.ThucTe <> v.TongThanhToan);
SET @Dat = CASE WHEN @ChiTiet IS NULL THEN 1 ELSE 0 END;
SET @ChiTiet = COALESCE(@ChiTiet, N'Kết quả trùng khớp');
EXEC #Ghi 'F10', N'F2 bằng vw_TienDonHang cho mọi đơn có chi tiết', @Dat, @ChiTiet;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT dbo.DON_HANG (NgayDatHang, TrangThaiDon, NgayGiaoDuKien, DiemSuDung, PhiVanChuyenChot,
                         TenNguoiNhan, DiaChiGiaoHang, SdtNguoiNhan, MaKhachHang, MaDiaChi,
                         MaPhuongThucVC, MaPhuongThucTT, MaChinhSachDiemChot)
    SELECT NgayDatHang, 'CHO_XAC_NHAN', NgayGiaoDuKien, 0, PhiVanChuyenChot,
           TenNguoiNhan, DiaChiGiaoHang, SdtNguoiNhan, MaKhachHang, MaDiaChi,
           MaPhuongThucVC, MaPhuongThucTT, MaChinhSachDiemChot
    FROM dbo.DON_HANG WHERE MaDonHang = 1;

    DECLARE @MaDonRong INT = CONVERT(INT, SCOPE_IDENTITY());
    DECLARE @Tong DECIMAL(18,2) = dbo.fn_TinhTongThanhToan(@MaDonRong);
    ROLLBACK TRANSACTION;

    SET @Dat = CASE WHEN @Tong = -3 THEN 1 ELSE 0 END;
    SET @ChiTiet = CONCAT(N'Kỳ vọng: -3, thực tế: ', COALESCE(CONVERT(VARCHAR(24), @Tong), 'NULL'));
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    SET @Dat = 0;
    SET @ChiTiet = ERROR_MESSAGE();
END CATCH;
EXEC #Ghi 'F11', N'Đơn tồn tại nhưng chưa có chi tiết', @Dat, @ChiTiet;
GO

/* Q2: đối chiếu truy vấn độc lập trên dữ liệu sau kiểm thử đơn hàng – điểm. */
DROP TABLE IF EXISTS #Q2;
CREATE TABLE #Q2 (
    MaSanPham INT, TenSanPham NVARCHAR(200), TenDanhMuc NVARCHAR(100), TenThuongHieu NVARCHAR(100),
    SoBienTheDaBan INT, SoDonHang INT, TongSoLuongBan BIGINT, DoanhThu DECIMAL(38,2), GiaBanTrungBinh DECIMAL(14,2)
);

DECLARE @Ca TABLE (
    Ma CHAR(3) PRIMARY KEY, MoTa NVARCHAR(200), MaDanhMuc INT, MaThuongHieu INT,
    TuNgay DATE, DenNgay DATE, SoLuong INT, DoanhThu DECIMAL(18,2)
);
INSERT @Ca VALUES
    ('Q01', N'Không lọc', NULL, NULL, NULL, NULL, NULL, NULL),
    ('Q02', N'Danh mục cha 1 gồm danh mục con 2, 3 và 7', 1, NULL, NULL, NULL, NULL, NULL),
    ('Q03', N'Thương hiệu 2', NULL, 2, NULL, NULL, NULL, NULL),
    ('Q04', N'Khoảng ngày mẫu đến hết 18/11/2026', NULL, NULL, '20260101', '20261118', NULL, NULL),
    ('Q05', N'Số lượng tối thiểu 2', NULL, NULL, NULL, NULL, 2, NULL),
    ('Q06', N'Doanh thu tối thiểu 796.000', NULL, NULL, NULL, NULL, NULL, 796000),
    ('Q07', N'Khoảng ngày không có kết quả', NULL, NULL, '20200101', '20200131', NULL, NULL),
    ('Q08', N'Tính cả đơn đặt buổi tối ngày kết thúc', NULL, NULL, '20260310', '20260310', NULL, NULL);

DECLARE @KyVong TABLE (
    MaSanPham INT PRIMARY KEY, TenSanPham NVARCHAR(200), TenDanhMuc NVARCHAR(100), TenThuongHieu NVARCHAR(100),
    SoBienTheDaBan INT, SoDonHang INT, TongSoLuongBan BIGINT, DoanhThu DECIMAL(38,2), GiaBanTrungBinh DECIMAL(14,2)
);
DECLARE @Mau TABLE (MaSanPham INT PRIMARY KEY, SoBienThe INT, SoDon INT, SoLuong BIGINT, DoanhThu DECIMAL(38,2));
INSERT @Mau VALUES (2, 2, 2, 2, 1798000), (1, 2, 2, 4, 796000), (3, 1, 1, 1, 350000), (5, 1, 1, 1, 150000);

DECLARE @Ma CHAR(3) = '', @MoTa NVARCHAR(200), @DanhMuc INT, @ThuongHieu INT, @Tu DATE, @Den DATE,
        @SoLuong INT, @DoanhThu DECIMAL(18,2), @Dat BIT, @ChiTiet NVARCHAR(2000);
WHILE EXISTS (SELECT 1 FROM @Ca WHERE Ma > @Ma)
BEGIN
    SELECT TOP (1) @Ma = Ma, @MoTa = MoTa, @DanhMuc = MaDanhMuc, @ThuongHieu = MaThuongHieu,
           @Tu = TuNgay, @Den = DenNgay, @SoLuong = SoLuong, @DoanhThu = DoanhThu
    FROM @Ca WHERE Ma > @Ma ORDER BY Ma;

    DELETE FROM #Q2;
    DELETE FROM @KyVong;
    INSERT #Q2
        EXEC dbo.sp_ThongKeBanTheoSanPham @DanhMuc, @ThuongHieu, @Tu, @Den, @SoLuong, @DoanhThu;

    WITH Ban AS (
        SELECT ct.MaSanPham, COUNT(DISTINCT ct.MaBienTheNoiBo) AS SoBienThe,
               COUNT(DISTINCT ct.MaDonHang) AS SoDon,
               SUM(CONVERT(BIGINT, ct.SoLuongMua)) AS SoLuong, SUM(ct.DonGiaLucDat * ct.SoLuongMua) AS DoanhThu
        FROM dbo.CHI_TIET_DON_HANG AS ct
        WHERE EXISTS (
            SELECT 1 FROM dbo.DON_HANG AS d
            WHERE d.MaDonHang = ct.MaDonHang AND d.TrangThaiDon = 'DA_GIAO'
              AND (@Tu IS NULL OR CONVERT(DATE, d.NgayDatHang) >= @Tu)
              AND (@Den IS NULL OR CONVERT(DATE, d.NgayDatHang) <= @Den)
        )
        GROUP BY ct.MaSanPham
    )
    INSERT @KyVong
    SELECT sp.MaSanPham, sp.TenSanPham, dm.TenDanhMuc, th.TenThuongHieu,
           b.SoBienThe, b.SoDon, b.SoLuong, b.DoanhThu, CONVERT(DECIMAL(14,2), b.DoanhThu / b.SoLuong)
    FROM Ban AS b
    JOIN dbo.SAN_PHAM AS sp ON sp.MaSanPham = b.MaSanPham
    JOIN dbo.DANH_MUC AS dm ON dm.MaDanhMuc = sp.MaDanhMuc
    JOIN dbo.THUONG_HIEU AS th ON th.MaThuongHieu = sp.MaThuongHieu
    WHERE (@DanhMuc IS NULL OR sp.MaDanhMuc IN (1, 2, 3, 7))
      AND (@ThuongHieu IS NULL OR sp.MaThuongHieu = @ThuongHieu)
      AND (@SoLuong IS NULL OR b.SoLuong >= @SoLuong)
      AND (@DoanhThu IS NULL OR b.DoanhThu >= @DoanhThu);

    SET @Dat = CASE WHEN (SELECT COUNT(*) FROM #Q2) <> (SELECT COUNT(*) FROM @KyVong)
                      OR EXISTS (SELECT * FROM #Q2 EXCEPT SELECT * FROM @KyVong)
                      OR EXISTS (SELECT * FROM @KyVong EXCEPT SELECT * FROM #Q2)
                    THEN 0 ELSE 1 END;
    SET @ChiTiet = CONCAT(N'Số dòng kỳ vọng: ', (SELECT COUNT(*) FROM @KyVong),
                          N', thực tế: ', (SELECT COUNT(*) FROM #Q2));
    EXEC #Ghi @Ma, @MoTa, @Dat, @ChiTiet;

    IF @Ma = 'Q04'
    BEGIN
        SET @Dat = CASE WHEN (SELECT COUNT(*) FROM #Q2) = 4
                          AND (SELECT SUM(DoanhThu) FROM #Q2) = 3094000
                          AND NOT EXISTS (
                              SELECT MaSanPham, SoBienTheDaBan, SoDonHang, TongSoLuongBan, DoanhThu FROM #Q2
                              EXCEPT SELECT MaSanPham, SoBienThe, SoDon, SoLuong, DoanhThu FROM @Mau
                          ) THEN 1 ELSE 0 END;
        SET @ChiTiet = CONCAT(N'Kỳ vọng 4 sản phẩm và doanh thu 3094000, thực tế: ',
                              (SELECT COUNT(*) FROM #Q2), N' sản phẩm, ', (SELECT SUM(DoanhThu) FROM #Q2));
        EXEC #Ghi 'Q04M', N'Số liệu mẫu cố định trong khoảng ngày', @Dat, @ChiTiet;
    END;
END;
GO

/* T16: các bảng nghiệp vụ đều phải có ít nhất 5 dòng. */
WITH SoDong AS (
    SELECT 'NGUOI_DUNG' AS Ten, COUNT(*) AS SoLuong FROM dbo.NGUOI_DUNG UNION ALL
    SELECT 'SDT_LIEN_LAC', COUNT(*) FROM dbo.SDT_LIEN_LAC UNION ALL
    SELECT 'KHACH_HANG', COUNT(*) FROM dbo.KHACH_HANG UNION ALL
    SELECT 'NHAN_VIEN', COUNT(*) FROM dbo.NHAN_VIEN UNION ALL
    SELECT 'DIA_CHI', COUNT(*) FROM dbo.DIA_CHI UNION ALL
    SELECT 'DANH_MUC', COUNT(*) FROM dbo.DANH_MUC UNION ALL
    SELECT 'THUONG_HIEU', COUNT(*) FROM dbo.THUONG_HIEU UNION ALL
    SELECT 'SAN_PHAM', COUNT(*) FROM dbo.SAN_PHAM UNION ALL
    SELECT 'HINH_ANH_SAN_PHAM', COUNT(*) FROM dbo.HINH_ANH_SAN_PHAM UNION ALL
    SELECT 'BIEN_THE_SAN_PHAM', COUNT(*) FROM dbo.BIEN_THE_SAN_PHAM UNION ALL
    SELECT 'GIO_HANG', COUNT(*) FROM dbo.GIO_HANG UNION ALL
    SELECT 'CHINH_SACH_DIEM', COUNT(*) FROM dbo.CHINH_SACH_DIEM UNION ALL
    SELECT 'DIEM_DANH_DANG_NHAP', COUNT(*) FROM dbo.DIEM_DANH_DANG_NHAP UNION ALL
    SELECT 'PHUONG_THUC_VAN_CHUYEN', COUNT(*) FROM dbo.PHUONG_THUC_VAN_CHUYEN UNION ALL
    SELECT 'PHUONG_THUC_THANH_TOAN', COUNT(*) FROM dbo.PHUONG_THUC_THANH_TOAN UNION ALL
    SELECT 'KHUYEN_MAI', COUNT(*) FROM dbo.KHUYEN_MAI UNION ALL
    SELECT 'DON_HANG', COUNT(*) FROM dbo.DON_HANG UNION ALL
    SELECT 'CHI_TIET_DON_HANG', COUNT(*) FROM dbo.CHI_TIET_DON_HANG UNION ALL
    SELECT 'AP_DUNG_KHUYEN_MAI', COUNT(*) FROM dbo.AP_DUNG_KHUYEN_MAI UNION ALL
    SELECT 'NHAT_KY_XU_LY_DON', COUNT(*) FROM dbo.NHAT_KY_XU_LY_DON UNION ALL
    SELECT 'DANH_GIA', COUNT(*) FROM dbo.DANH_GIA UNION ALL
    SELECT 'TEP_DANH_GIA', COUNT(*) FROM dbo.TEP_DANH_GIA
)
INSERT #KQ (Ma, Dat, MoTa, ChiTiet)
SELECT 'DL', CASE WHEN SoLuong >= 5 THEN 1 ELSE 0 END, Ten,
       CONCAT(N'Kỳ vọng ít nhất 5 dòng, thực tế: ', SoLuong)
FROM SoDong;

SELECT COUNT(*) AS TongSoCa, SUM(CONVERT(INT, Dat)) AS SoPass,
       COUNT(*) - SUM(CONVERT(INT, Dat)) AS SoFail
FROM #KQ;
SELECT Ma, MoTa, ChiTiet FROM #KQ WHERE Dat = 0 ORDER BY STT;
IF EXISTS (SELECT 1 FROM #KQ WHERE Dat = 0)
    THROW 50599, N'Kiểm thử thống kê, thanh toán hoặc dữ liệu mẫu có ca thất bại.', 1;
GO
