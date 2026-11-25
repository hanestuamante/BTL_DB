/* =====================================================================
   30_sp_thong_ke_ban.sql — T30 (Lê Viễn Bằng)
   Q2: doanh thu gộp = Σ số lượng × đơn giá lúc đặt, trước mọi giảm giá.
   Chỉ tính đơn đã giao; giá bán trung bình tính theo số lượng.
   Ngày kết thúc được tính trọn ngày: [Từ ngày, Đến ngày + 1).
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

CREATE OR ALTER PROCEDURE dbo.sp_ThongKeBanTheoSanPham
    @MaDanhMuc          INT = NULL,
    @MaThuongHieu       INT = NULL,
    @TuNgay             DATE = NULL,
    @DenNgay            DATE = NULL,
    @SoLuongToiThieu    INT = NULL,
    @DoanhThuToiThieu   DECIMAL(18,2) = NULL
AS
WITH DanhMucLoc AS (
    SELECT MaDanhMuc
    FROM dbo.DANH_MUC
    WHERE MaDanhMuc = @MaDanhMuc

    UNION ALL

    SELECT dm.MaDanhMuc
    FROM dbo.DANH_MUC AS dm
    JOIN DanhMucLoc AS cha ON cha.MaDanhMuc = dm.MaDanhMucCha
)
SELECT sp.MaSanPham, sp.TenSanPham, dm.TenDanhMuc, th.TenThuongHieu,
       COUNT(DISTINCT bt.MaBienTheNoiBo) AS SoBienTheDaBan,
       COUNT(DISTINCT d.MaDonHang) AS SoDonHang,
       SUM(CONVERT(BIGINT, ct.SoLuongMua)) AS TongSoLuongBan,
       SUM(ct.SoLuongMua * ct.DonGiaLucDat) AS DoanhThu,
       CAST(SUM(ct.SoLuongMua * ct.DonGiaLucDat)
            / SUM(CONVERT(BIGINT, ct.SoLuongMua)) AS DECIMAL(14,2)) AS GiaBanTrungBinh
FROM dbo.CHI_TIET_DON_HANG AS ct
JOIN dbo.DON_HANG AS d ON d.MaDonHang = ct.MaDonHang
JOIN dbo.BIEN_THE_SAN_PHAM AS bt ON bt.MaSanPham = ct.MaSanPham
                               AND bt.MaBienTheNoiBo = ct.MaBienTheNoiBo
JOIN dbo.SAN_PHAM AS sp ON sp.MaSanPham = bt.MaSanPham
JOIN dbo.DANH_MUC AS dm ON dm.MaDanhMuc = sp.MaDanhMuc
JOIN dbo.THUONG_HIEU AS th ON th.MaThuongHieu = sp.MaThuongHieu
WHERE d.TrangThaiDon = 'DA_GIAO'
  AND (@MaDanhMuc IS NULL OR dm.MaDanhMuc IN (SELECT MaDanhMuc FROM DanhMucLoc))
  AND (@MaThuongHieu IS NULL OR th.MaThuongHieu = @MaThuongHieu)
  AND (@TuNgay IS NULL OR d.NgayDatHang >= @TuNgay)
  AND (@DenNgay IS NULL OR @DenNgay = '99991231'
       OR d.NgayDatHang < DATEADD(DAY, 1, NULLIF(@DenNgay, '99991231')))
GROUP BY sp.MaSanPham, sp.TenSanPham, dm.TenDanhMuc, th.TenThuongHieu
HAVING (@SoLuongToiThieu IS NULL OR SUM(CONVERT(BIGINT, ct.SoLuongMua)) >= @SoLuongToiThieu)
   AND (@DoanhThuToiThieu IS NULL OR SUM(ct.SoLuongMua * ct.DonGiaLucDat) >= @DoanhThuToiThieu)
ORDER BY DoanhThu DESC, sp.MaSanPham
OPTION (MAXRECURSION 0);
GO
