/* =====================================================================
   90_kiem_thu_dan_xuat_nghiep_vu.sql — T37 (Khưu Huỳnh Gia Hưng)
   Kiểm thử trigger thuộc tính dẫn xuất T25 (SAN_PHAM.TongSoLuongDaBan) và trigger nghiệp vụ
   T24 của Đại (trg_DanhGia_KiemTraQuyen), với thao tác một dòng và nhiều dòng.

   Bất biến của T25: với mọi sản phẩm p,
     TongSoLuongDaBan(p) = Σ SoLuongMua của các dòng chi tiết thuộc p nằm trong đơn DA_GIAO.
   Số liệu sau dữ liệu mẫu: SP1 = 4, SP2 = 2, SP3 = 1, SP4 = 0, SP5 = 1, SP6 = 0.

   CÁCH CHẠY: chạy cùng các file khác theo lệnh "Chạy toàn bộ" ở README (tên bắt đầu bằng "dan"
   nên chạy trước 90_kiem_thu_don_hang_diem.sql). File KHÔNG để lại thay đổi dữ liệu: mọi ca có
   sửa dữ liệu bọc trong BEGIN TRAN … ROLLBACK; DX10 ở cuối kiểm lại 6 số ban đầu.
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
IF OBJECT_ID('tempdb..#KiemDaBan') IS NOT NULL DROP PROCEDURE #KiemDaBan;
GO
/* So TongSoLuongDaBan với kỳ vọng '<MaSP>:<số>;…' VÀ với giá trị tính lại cho MỌI sản phẩm.
   Sai thì THROW 50399 kèm giá trị thật. */
CREATE PROCEDURE #KiemDaBan @KyVong NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sai NVARCHAR(1000), @Lech NVARCHAR(1000), @Msg NVARCHAR(2048);

    SELECT @Sai = STRING_AGG(CONCAT('SP', sp.MaSanPham, '=', sp.TongSoLuongDaBan, N' (kỳ vọng ', k.KyVong, ')'), '; ')
    FROM (SELECT CAST(LEFT(value, CHARINDEX(':', value) - 1) AS INT) AS Ma,
                 CAST(SUBSTRING(value, CHARINDEX(':', value) + 1, 10) AS INT) AS KyVong
          FROM STRING_SPLIT(@KyVong, ';')) k
    JOIN dbo.SAN_PHAM sp ON sp.MaSanPham = k.Ma
    WHERE sp.TongSoLuongDaBan <> k.KyVong;

    SELECT @Lech = STRING_AGG(CONCAT('SP', sp.MaSanPham, N' lưu ', sp.TongSoLuongDaBan, N', tính lại ', ISNULL(x.SoLuong, 0)), '; ')
    FROM dbo.SAN_PHAM sp
    OUTER APPLY (SELECT SUM(c.SoLuongMua) AS SoLuong
                 FROM dbo.CHI_TIET_DON_HANG c
                 JOIN dbo.DON_HANG d ON d.MaDonHang = c.MaDonHang
                 WHERE c.MaSanPham = sp.MaSanPham AND d.TrangThaiDon = 'DA_GIAO') x
    WHERE sp.TongSoLuongDaBan <> ISNULL(x.SoLuong, 0);

    IF @Sai IS NOT NULL OR @Lech IS NOT NULL
    BEGIN
        SET @Msg = CONCAT(N'Sai kỳ vọng: ', ISNULL(@Sai, N'không'), N' | Lệch với tính lại: ', ISNULL(@Lech, N'không'));
        THROW 50399, @Msg, 1;
    END;
END;
GO

/* =====================================================================
   DX. TRIGGER THUỘC TÍNH DẪN XUẤT T25 (một dòng và nhiều dòng)
   ===================================================================== */
EXEC #KyVongOK 'DX1', N'Sau dữ liệu mẫu: đúng 6 số và bằng phép tính lại',
     N'EXEC #KiemDaBan ''1:4;2:2;3:1;4:0;5:1;6:0'';';
EXEC #KyVongOK 'DX2', N'Một câu INSERT 2 dòng vào đơn 1 (DA_GIAO)', N'BEGIN TRAN;
INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot, MaSanPham, MaBienTheNoiBo) VALUES
 (1, 2, 2, 590000, N''Xanh navy'',  N''L'',         4, ''XANH-L''),
 (1, 3, 3,  80000, N''Trong suốt'', N''iPhone 15'', 6, ''TRONG-IP15'');
EXEC #KiemDaBan ''4:2;6:3'';
ROLLBACK;';
EXEC #KyVongOK 'DX3', N'INSERT vào đơn 7 (chưa giao) không làm đổi số đã bán', N'BEGIN TRAN;
INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot, MaSanPham, MaBienTheNoiBo) VALUES
 (7, 3, 1, 350000, N''Trắng'', N''20W'', 3, ''TRANG-20W'');
EXEC #KiemDaBan ''3:1'';
ROLLBACK;';
EXEC #KyVongOK 'DX4', N'Đơn 5 chuyển sang DA_GIAO qua sp_CapNhatTrangThaiDon', N'BEGIN TRAN;
EXEC dbo.sp_CapNhatTrangThaiDon 5, ''DA_GIAO'', ''NhanVien'', ''NV02'';
EXEC #KiemDaBan ''4:1'';
ROLLBACK;';
EXEC #KyVongOK 'DX5', N'Hủy đơn 7 (chưa giao) không làm đổi số đã bán', N'BEGIN TRAN;
EXEC dbo.sp_CapNhatTrangThaiDon 7, ''DA_HUY'', ''KhachHang'';
EXEC #KiemDaBan ''1:4;5:1'';
ROLLBACK;';
EXEC #KyVongOK 'DX6', N'Sửa số lượng dòng (1,1) từ 2 thành 5', N'BEGIN TRAN;
UPDATE dbo.CHI_TIET_DON_HANG SET SoLuongMua = 5 WHERE MaDonHang = 1 AND SoThuTuDong = 1;
EXEC #KiemDaBan ''1:7'';
ROLLBACK;';
EXEC #KyVongOK 'DX7', N'Đổi sản phẩm của dòng (1,1) từ SP1 sang SP5', N'BEGIN TRAN;
UPDATE dbo.CHI_TIET_DON_HANG SET MaSanPham = 5, MaBienTheNoiBo = ''DEN-1M'', MauSacChot = N''Đen'', KichCoChot = N''1m''
WHERE MaDonHang = 1 AND SoThuTuDong = 1;
EXEC #KiemDaBan ''1:2;5:3'';
ROLLBACK;';
EXEC #KyVongOK 'DX8', N'Xóa dòng (3,2) của đơn đã giao', N'BEGIN TRAN;
DELETE dbo.DANH_GIA WHERE MaDonHang = 3 AND SoThuTuDong = 2;
DELETE dbo.CHI_TIET_DON_HANG WHERE MaDonHang = 3 AND SoThuTuDong = 2;
EXEC #KiemDaBan ''1:2'';
ROLLBACK;';
EXEC #KyVongOK 'DX9', N'Một câu UPDATE đưa 2 đơn (5, 8) sang DA_GIAO', N'BEGIN TRAN;
UPDATE dbo.DON_HANG SET TrangThaiDon = ''DA_GIAO'' WHERE MaDonHang IN (5, 8);
EXEC #KiemDaBan ''4:1;1:6'';
ROLLBACK;';
GO

/* =====================================================================
   NV. TRIGGER NGHIỆP VỤ T24 CỦA ĐẠI (trg_DanhGia_KiemTraQuyen), một dòng và nhiều dòng
   Đơn 1 giao lúc 2026-02-08 16:00; đơn 5 đang giao.
   ===================================================================== */
EXEC #KyVongLoi 'NV1', N'Đánh giá dòng của đơn chưa giao (đơn 5)', 50160, N'BEGIN TRAN;
INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, MaDonHang, SoThuTuDong) VALUES (5, ''2026-11-21'', 5, 1);
ROLLBACK;';
EXEC #KyVongLoi 'NV2', N'Một câu INSERT 2 đánh giá, 1 hợp lệ + 1 không: cả câu bị từ chối', 50160, N'BEGIN TRAN;
INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot, MaSanPham, MaBienTheNoiBo) VALUES
 (1, 2, 2, 590000, N''Xanh navy'', N''L'', 4, ''XANH-L'');
INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, MaDonHang, SoThuTuDong) VALUES (4, ''2026-03-01'', 1, 2), (5, ''2026-11-21'', 5, 1);
ROLLBACK;';
EXEC #KyVongOK 'NV3', N'Một câu INSERT 2 đánh giá hợp lệ cho đơn đã giao', N'BEGIN TRAN;
INSERT dbo.CHI_TIET_DON_HANG (MaDonHang, SoThuTuDong, SoLuongMua, DonGiaLucDat, MauSacChot, KichCoChot, MaSanPham, MaBienTheNoiBo) VALUES
 (1, 2, 2, 590000, N''Xanh navy'',  N''L'',         4, ''XANH-L''),
 (1, 3, 3,  80000, N''Trong suốt'', N''iPhone 15'', 6, ''TRONG-IP15'');
INSERT dbo.DANH_GIA (SoSao, ThoiGianDanhGia, MaDonHang, SoThuTuDong) VALUES (4, ''2026-03-01'', 1, 2), (5, ''2026-03-01'', 1, 3);
IF (SELECT COUNT(*) FROM dbo.DANH_GIA WHERE MaDonHang = 1) <> 3 THROW 50399, N''Đơn 1 không có đủ 3 đánh giá.'', 1;
ROLLBACK;';
EXEC #KyVongLoi 'NV4', N'Sửa thời gian đánh giá về trước mốc giao (đơn 1)', 50161, N'BEGIN TRAN;
UPDATE dbo.DANH_GIA SET ThoiGianDanhGia = ''2026-02-01'' WHERE MaDonHang = 1 AND SoThuTuDong = 1;
ROLLBACK;';
EXEC #KyVongOK 'NV5', N'Sửa lượt hữu ích của cả 6 đánh giá trong một câu', N'BEGIN TRAN;
DECLARE @TruocDo INT = (SELECT SUM(SoLuotBamHuuIch) FROM dbo.DANH_GIA), @SoDanhGia INT = (SELECT COUNT(*) FROM dbo.DANH_GIA);
UPDATE dbo.DANH_GIA SET SoLuotBamHuuIch = SoLuotBamHuuIch + 1;
IF @SoDanhGia <> 6 OR (SELECT SUM(SoLuotBamHuuIch) FROM dbo.DANH_GIA) <> @TruocDo + 6
    THROW 50399, N''Không sửa đúng 6 đánh giá.'', 1;
ROLLBACK;';
GO

/* =====================================================================
   DX10. ĐẶT CUỐI FILE: file này không để lại thay đổi dữ liệu
   ===================================================================== */
EXEC #KyVongOK 'DX10', N'Cuối file: vẫn đúng 6 số ban đầu và bằng phép tính lại',
     N'EXEC #KiemDaBan ''1:4;2:2;3:1;4:0;5:1;6:0'';';
GO

/* ---------- TỔNG HỢP ---------- */
SELECT COUNT(*) AS TongSoCa, SUM(CAST(Dat AS INT)) AS SoPass, COUNT(*) - SUM(CAST(Dat AS INT)) AS SoFail FROM #KQ;
SELECT Ma, MoTa, ChiTiet FROM #KQ WHERE Dat = 0 ORDER BY STT;
GO
