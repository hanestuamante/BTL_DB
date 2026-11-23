/* =====================================================================
   25_trigger_dan_xuat.sql — T25 (Khưu Huỳnh Gia Hưng)
   Trigger duy trì thuộc tính dẫn xuất SAN_PHAM.TongSoLuongDaBan (BTL2 mục 2.2.2):
     trg_ChiTietDonHang_TongDaBan   AFTER INSERT, UPDATE, DELETE trên CHI_TIET_DON_HANG
     trg_DonHang_TongDaBan          AFTER UPDATE (TrangThaiDon) trên DON_HANG

   Bất biến: với mọi sản phẩm p,
     TongSoLuongDaBan(p) = Σ SoLuongMua của các dòng chi tiết thuộc p nằm trong đơn có TrangThaiDon = 'DA_GIAO'.

   Cách làm: lấy TẬP sản phẩm bị ảnh hưởng rồi TÍNH LẠI tổng của đúng các sản phẩm đó,
   thay vì cộng / trừ chênh lệch. Nhờ vậy thao tác nhiều dòng, đổi sản phẩm của một dòng,
   hay vừa đổi số lượng vừa đổi đơn đều đúng mà không phải xử lý riêng từng trường hợp.
   Trigger trên chi tiết bắt cả INSERT vì dữ liệu mẫu chèn thẳng đơn DA_GIAO rồi mới chèn chi tiết.
   Chạy SAU 12 (SAN_PHAM) và 13 (DON_HANG, CHI_TIET_DON_HANG).
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   trg_ChiTietDonHang_TongDaBan — Người viết: Khưu Huỳnh Gia Hưng
   Sản phẩm bị ảnh hưởng = MaSanPham của các dòng trong inserted ∪ deleted.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_ChiTietDonHang_TongDaBan
ON dbo.CHI_TIET_DON_HANG
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    -- UPDATE không đụng tới số lượng, sản phẩm hay đơn thì tổng không đổi
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
       AND NOT (UPDATE(SoLuongMua) OR UPDATE(MaSanPham) OR UPDATE(MaDonHang))
        RETURN;

    WITH SanPhamAnhHuong AS (
        SELECT MaSanPham FROM inserted
        UNION
        SELECT MaSanPham FROM deleted
    )
    UPDATE sp
    SET TongSoLuongDaBan = ISNULL(x.SoLuong, 0)
    FROM dbo.SAN_PHAM sp
    JOIN SanPhamAnhHuong a ON a.MaSanPham = sp.MaSanPham
    OUTER APPLY (SELECT SUM(c.SoLuongMua) AS SoLuong
                 FROM dbo.CHI_TIET_DON_HANG c
                 JOIN dbo.DON_HANG d ON d.MaDonHang = c.MaDonHang
                 WHERE c.MaSanPham = sp.MaSanPham
                   AND d.TrangThaiDon = 'DA_GIAO') x;
END;
GO

/* ---------------------------------------------------------------------
   trg_DonHang_TongDaBan — Người viết: Khưu Huỳnh Gia Hưng
   Chỉ các đơn vừa vào hoặc vừa ra khỏi trạng thái DA_GIAO mới làm đổi tổng
   (trên thực tế DA_GIAO là trạng thái cuối, trg_DonHang_KiemTra của Đại chặn việc rời khỏi nó).
   Sản phẩm bị ảnh hưởng = sản phẩm của các dòng chi tiết thuộc những đơn đó.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_DonHang_TongDaBan
ON dbo.DON_HANG
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TrangThaiDon) RETURN;

    WITH DonDoiTrangThaiGiao AS (
        SELECT i.MaDonHang
        FROM inserted i
        JOIN deleted d ON d.MaDonHang = i.MaDonHang
        WHERE CASE WHEN i.TrangThaiDon = 'DA_GIAO' THEN 1 ELSE 0 END
           <> CASE WHEN d.TrangThaiDon = 'DA_GIAO' THEN 1 ELSE 0 END
    ),
    SanPhamAnhHuong AS (
        SELECT DISTINCT c.MaSanPham
        FROM dbo.CHI_TIET_DON_HANG c
        JOIN DonDoiTrangThaiGiao o ON o.MaDonHang = c.MaDonHang
    )
    UPDATE sp
    SET TongSoLuongDaBan = ISNULL(x.SoLuong, 0)
    FROM dbo.SAN_PHAM sp
    JOIN SanPhamAnhHuong a ON a.MaSanPham = sp.MaSanPham
    OUTER APPLY (SELECT SUM(c.SoLuongMua) AS SoLuong
                 FROM dbo.CHI_TIET_DON_HANG c
                 JOIN dbo.DON_HANG d ON d.MaDonHang = c.MaDonHang
                 WHERE c.MaSanPham = sp.MaSanPham
                   AND d.TrangThaiDon = 'DA_GIAO') x;
END;
GO
PRINT N'25: Đã tạo 2 trigger duy trì SAN_PHAM.TongSoLuongDaBan.';
GO
