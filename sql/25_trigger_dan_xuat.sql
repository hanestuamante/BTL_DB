/* =====================================================================
   25_trigger_dan_xuat.sql — T25 (Khưu Huỳnh Gia Hưng)
   Trigger duy trì thuộc tính dẫn xuất SAN_PHAM.TongSoLuongDaBan (BTL2 mục 2.2.2):
     trg_ChiTietDonHang_TongDaBan   AFTER INSERT, UPDATE, DELETE trên CHI_TIET_DON_HANG
     trg_DonHang_TongDaBan          AFTER UPDATE (TrangThaiDon) trên DON_HANG
     trg_SanPham_KiemTraDaBan       AFTER INSERT, UPDATE trên SAN_PHAM: không ghi tay giá trị sai (50250)

   Bất biến: với mọi sản phẩm p,
     TongSoLuongDaBan(p) = Σ SoLuongMua của các dòng chi tiết thuộc p nằm trong đơn có TrangThaiDon = 'DA_GIAO'.

   Cách làm: lấy TẬP sản phẩm bị ảnh hưởng rồi TÍNH LẠI tổng của đúng các sản phẩm đó,
   thay vì cộng / trừ chênh lệch. Nhờ vậy thao tác nhiều dòng, đổi sản phẩm của một dòng,
   hay vừa đổi số lượng vừa đổi đơn đều đúng mà không phải xử lý riêng từng trường hợp.
   Trigger trên chi tiết bắt cả INSERT: thêm dòng vào một đơn đã giao (ví dụ dữ liệu mẫu chèn thẳng
   đơn DA_GIAO rồi mới chèn chi tiết) phải làm tổng đổi ngay; ca DX2 kiểm điều này.
   Chạy SAU 12 (SAN_PHAM) và 13 (DON_HANG, CHI_TIET_DON_HANG).
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   trg_ChiTietDonHang_TongDaBan — Người viết: Khưu Huỳnh Gia Hưng
   Sản phẩm bị ảnh hưởng = MaSanPham của các dòng trong inserted ∪ deleted mà đơn của dòng đó
   đang ở DA_GIAO (dòng của đơn chưa giao không nằm trong tổng nên không làm tổng đổi).
   Nhờ lọc này, sp_TaoDonHang (đơn mới luôn chưa giao) không phải đọc dòng của phiên khác
   và không khóa SAN_PHAM, nên trigger không làm các phiên đặt đơn chờ nhau.
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

    WITH DongThayDoi AS (
        SELECT MaDonHang, MaSanPham FROM inserted
        UNION
        SELECT MaDonHang, MaSanPham FROM deleted
    ),
    SanPhamAnhHuong AS (
        SELECT DISTINCT t.MaSanPham
        FROM DongThayDoi t
        JOIN dbo.DON_HANG d ON d.MaDonHang = t.MaDonHang
        WHERE d.TrangThaiDon = 'DA_GIAO'
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
/* ---------------------------------------------------------------------
   trg_SanPham_KiemTraDaBan — Người viết: Khưu Huỳnh Gia Hưng
   TongSoLuongDaBan là thuộc tính dẫn xuất: chỉ chấp nhận giá trị bằng đúng định nghĩa.
   Ghi tay giá trị sai (UPDATE, hoặc INSERT sản phẩm mới với số khác 0) bị từ chối (50250).
   Ghi lại đúng giá trị (như lệnh đồng bộ ở cuối file 40, hay chính hai trigger trên) vẫn được.
   Chỉ kiểm khi câu lệnh đụng tới cột này, nên sửa giá, tên sản phẩm không tốn thêm gì.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_SanPham_KiemTraDaBan
ON dbo.SAN_PHAM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(TongSoLuongDaBan) RETURN;

    DECLARE @Loi NVARCHAR(400);
    SELECT TOP (1) @Loi = CONCAT(N'TongSoLuongDaBan của sản phẩm ', i.MaSanPham,
                                 N' là thuộc tính dẫn xuất, phải bằng ', ISNULL(x.SoLuong, 0),
                                 N' (tổng số lượng trong các đơn đã giao), không ghi tay giá trị ', i.TongSoLuongDaBan, N'.')
    FROM inserted i
    OUTER APPLY (SELECT SUM(c.SoLuongMua) AS SoLuong
                 FROM dbo.CHI_TIET_DON_HANG c
                 JOIN dbo.DON_HANG d ON d.MaDonHang = c.MaDonHang
                 WHERE c.MaSanPham = i.MaSanPham
                   AND d.TrangThaiDon = 'DA_GIAO') x
    WHERE i.TongSoLuongDaBan <> ISNULL(x.SoLuong, 0);

    IF @Loi IS NOT NULL THROW 50250, @Loi, 1;
END;
GO
PRINT N'25: Đã tạo 3 trigger duy trì và bảo vệ SAN_PHAM.TongSoLuongDaBan.';
GO
