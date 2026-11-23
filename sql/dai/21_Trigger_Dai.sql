/* =====================================================================
   21_Trigger_Dai.sql — Võ Quốc Đại
   Trigger cho các ràng buộc LIÊN BẢNG (không kiểm tra được bằng CHECK/FK):
     trg_DanhGia_KiemTraQuyen        T24 — trigger nghiệp vụ chính (RB1)
     trg_ApDungKhuyenMai_KiemTra     T23 — RB5, RB6, RB8
     trg_DonHang_KiemTra             chính sách chốt hợp lệ; DA_GIAO/DA_HUY là trạng thái cuối
     trg_NhatKy_ChiThem              nhật ký chỉ được thêm (bảo vệ mốc giao hàng dùng cho RB1)
     trg_NhatKy_KiemTraNhanVien      RB16 — nhân viên không xử lý đơn do chính mình đặt
     trg_ChinhSachDiem_KiemTra       phiên bản chính sách không chồng lấn, không sửa khi đã chốt
     trg_DiemDanh_KiemTraChinhSach   chính sách chốt phải hiệu lực tại thời điểm đăng nhập
   Mọi trigger xử lý tập dòng (bảng inserted/deleted), đúng cho INSERT/UPDATE nhiều dòng.
   Trong trigger, THROW hủy toàn bộ giao dịch của câu lệnh gây lỗi (XACT_ABORT mặc định ON).
   Mã lỗi: 50150–50159 voucher, 50160–50169 đánh giá, 50170–50189 chính sách/điểm danh,
           50190–50199 đơn hàng/nhật ký.
   ===================================================================== */
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   T24 — trg_DanhGia_KiemTraQuyen
   Ràng buộc (RB1): chỉ được đánh giá một dòng CHI_TIET_DON_HANG khi đơn chứa dòng đó
   đang ở DA_GIAO, và ThoiGianDanhGia phải SAU thời điểm nhật ký ghi nhận đơn
   chuyển sang DA_GIAO; không được ghi thời gian đánh giá ở tương lai.
   Các thao tác DML có thể vi phạm:
     - INSERT DANH_GIA                         → trigger này
     - UPDATE DANH_GIA (MaDonHang, SoThuTuDong, ThoiGianDanhGia) → trigger này
     - UPDATE DON_HANG.TrangThaiDon rời DA_GIAO → chặn bởi trg_DonHang_KiemTra
     - UPDATE/DELETE NHAT_KY_XU_LY_DON (đổi/xóa mốc giao) → chặn bởi trg_NhatKy_ChiThem
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_DanhGia_KiemTraQuyen
ON dbo.DANH_GIA
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    -- UPDATE chỉ đổi số lượt hữu ích / nội dung thì không cần kiểm tra lại
    IF NOT (UPDATE(MaDonHang) OR UPDATE(SoThuTuDong) OR UPDATE(ThoiGianDanhGia)) RETURN;

    DECLARE @Loi NVARCHAR(400);

    -- (1) Đơn phải ở trạng thái DA_GIAO
    SELECT TOP (1) @Loi = CONCAT(N'Không thể đánh giá dòng ', i.SoThuTuDong, N' của đơn ', i.MaDonHang,
                                 N': đơn đang ở trạng thái ', d.TrangThaiDon,
                                 N', chỉ đơn đã giao (DA_GIAO) mới được đánh giá.')
    FROM inserted i
    JOIN dbo.DON_HANG d ON d.MaDonHang = i.MaDonHang
    WHERE d.TrangThaiDon <> 'DA_GIAO';
    IF @Loi IS NOT NULL THROW 50160, @Loi, 1;

    -- (2) Thời gian đánh giá phải sau mốc giao hàng trong nhật ký
    SELECT TOP (1) @Loi =
        CASE WHEN g.ThoiDiemGiao IS NULL
             THEN CONCAT(N'Không thể đánh giá đơn ', i.MaDonHang,
                         N': không tìm thấy nhật ký ghi nhận đơn chuyển sang DA_GIAO.')
             ELSE CONCAT(N'Thời gian đánh giá (', CONVERT(VARCHAR(19), i.ThoiGianDanhGia, 120),
                         N') phải sau thời điểm giao hàng thành công của đơn ', i.MaDonHang,
                         N' (', CONVERT(VARCHAR(19), g.ThoiDiemGiao, 120), N').')
        END
    FROM inserted i
    OUTER APPLY (SELECT MAX(nk.ThoiDiem) AS ThoiDiemGiao
                 FROM dbo.NHAT_KY_XU_LY_DON nk
                 WHERE nk.MaDonHang = i.MaDonHang AND nk.TrangThaiSau = 'DA_GIAO') g
    WHERE g.ThoiDiemGiao IS NULL OR i.ThoiGianDanhGia <= g.ThoiDiemGiao;
    IF @Loi IS NOT NULL THROW 50161, @Loi, 1;

    -- (3) Không ghi thời gian đánh giá ở tương lai (cho phép lệch đồng hồ 5 phút)
    SELECT TOP (1) @Loi = CONCAT(N'Thời gian đánh giá của đơn ', i.MaDonHang, N' (',
                                 CONVERT(VARCHAR(19), i.ThoiGianDanhGia, 120), N') nằm ở tương lai.')
    FROM inserted i
    WHERE i.ThoiGianDanhGia > DATEADD(MINUTE, 5, dbo.fn_ThoiDiemVN());
    IF @Loi IS NOT NULL THROW 50162, @Loi, 1;
END;
GO

/* ---------------------------------------------------------------------
   T23 — trg_ApDungKhuyenMai_KiemTra
   RB5: tổng tiền hàng của đơn >= GiaTriDonToiThieu của voucher
   RB8: NgayDatHang của đơn nằm trong [NgayBatDau, NgayKetThuc] của voucher
   RB6: TienGiamChot <= GiaTriGiamGia; Σ TienGiamChot của đơn <= tổng tiền hàng
   DML vi phạm: INSERT/UPDATE AP_DUNG_KHUYEN_MAI. (Sửa/xóa CHI_TIET_DON_HANG sau khi đặt
   không được ứng dụng cho phép — mọi thay đổi đơn đi qua sp_TaoDonHang/sp_CapNhatTrangThaiDon.)
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_ApDungKhuyenMai_KiemTra
ON dbo.AP_DUNG_KHUYEN_MAI
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    DECLARE @Loi NVARCHAR(400);

    -- RB5 + RB8 (dùng chung logic với sp_TaoDonHang qua fn_KiemTraVoucher)
    SELECT TOP (1) @Loi = CONCAT(N'Đơn ', i.MaDonHang, N': ', k.Loi)
    FROM inserted i
    JOIN dbo.DON_HANG d ON d.MaDonHang = i.MaDonHang
    OUTER APPLY (SELECT ISNULL(SUM(c.SoLuongMua * c.DonGiaLucDat), 0) AS TongTienHang
                 FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaDonHang = i.MaDonHang) h
    CROSS APPLY (SELECT dbo.fn_KiemTraVoucher(i.MaVoucher, h.TongTienHang, d.NgayDatHang) AS Loi) k
    WHERE k.Loi IS NOT NULL;
    IF @Loi IS NOT NULL THROW 50150, @Loi, 1;

    -- RB6a: tiền giảm từng voucher không vượt giá trị voucher
    SELECT TOP (1) @Loi = CONCAT(N'Đơn ', i.MaDonHang, N': tiền giảm ', FORMAT(i.TienGiamChot, 'N0'),
                                 N'đ vượt giá trị tối đa ', FORMAT(km.GiaTriGiamGia, 'N0'),
                                 N'đ của voucher "', i.MaVoucher, N'".')
    FROM inserted i
    JOIN dbo.KHUYEN_MAI km ON km.MaVoucher = i.MaVoucher
    WHERE i.TienGiamChot > km.GiaTriGiamGia;
    IF @Loi IS NOT NULL THROW 50151, @Loi, 1;

    -- RB6b: tổng tiền giảm của đơn không vượt tổng tiền hàng
    SELECT TOP (1) @Loi = CONCAT(N'Đơn ', x.MaDonHang, N': tổng tiền giảm voucher ', FORMAT(v.TongGiam, 'N0'),
                                 N'đ vượt tổng tiền hàng ', FORMAT(h.TongTienHang, 'N0'), N'đ.')
    FROM (SELECT DISTINCT MaDonHang FROM inserted) x
    CROSS APPLY (SELECT SUM(a.TienGiamChot) AS TongGiam
                 FROM dbo.AP_DUNG_KHUYEN_MAI a WHERE a.MaDonHang = x.MaDonHang) v
    CROSS APPLY (SELECT ISNULL(SUM(c.SoLuongMua * c.DonGiaLucDat), 0) AS TongTienHang
                 FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaDonHang = x.MaDonHang) h
    WHERE v.TongGiam > h.TongTienHang;
    IF @Loi IS NOT NULL THROW 50152, @Loi, 1;
END;
GO

/* ---------------------------------------------------------------------
   trg_DonHang_KiemTra
   (a) Chính sách điểm chốt phải là phiên bản hiệu lực tại NgayDatHang.
   (b) DA_GIAO và DA_HUY là trạng thái cuối: không được đổi sang trạng thái khác
       (bảo vệ RB1 và bảo đảm hoàn tồn kho chỉ một lần khi hủy).
   Thứ tự chuyển trạng thái đầy đủ (RB15) được kiểm tra trong sp_CapNhatTrangThaiDon.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_DonHang_KiemTra
ON dbo.DON_HANG
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    DECLARE @Loi NVARCHAR(400);

    IF UPDATE(MaChinhSachDiemChot) OR UPDATE(NgayDatHang)
    BEGIN
        SELECT TOP (1) @Loi = CONCAT(N'Đơn ', i.MaDonHang, N': chính sách điểm ', i.MaChinhSachDiemChot,
                                     N' không có hiệu lực tại thời điểm đặt hàng ',
                                     CONVERT(VARCHAR(19), i.NgayDatHang, 120), N'.')
        FROM inserted i
        JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = i.MaChinhSachDiemChot
        WHERE i.NgayDatHang < cs.HieuLucTu
           OR (cs.HieuLucDen IS NOT NULL AND i.NgayDatHang >= cs.HieuLucDen);
        IF @Loi IS NOT NULL THROW 50190, @Loi, 1;
    END;

    IF UPDATE(TrangThaiDon)
    BEGIN
        SELECT TOP (1) @Loi = CONCAT(N'Đơn ', i.MaDonHang, N' đã ở trạng thái kết thúc ', d.TrangThaiDon,
                                     N', không thể chuyển sang ', i.TrangThaiDon, N'.')
        FROM inserted i
        JOIN deleted d ON d.MaDonHang = i.MaDonHang
        WHERE d.TrangThaiDon IN ('DA_GIAO', 'DA_HUY')
          AND i.TrangThaiDon <> d.TrangThaiDon;
        IF @Loi IS NOT NULL THROW 50191, @Loi, 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   trg_NhatKy_ChiThem — nhật ký xử lý đơn là bằng chứng nghiệp vụ, chỉ được thêm.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_ChiThem
ON dbo.NHAT_KY_XU_LY_DON
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 50192, N'Nhật ký xử lý đơn chỉ được thêm mới, không được sửa hoặc xóa (mốc thời gian dùng để kiểm tra quyền đánh giá).', 1;
END;
GO

/* ---------------------------------------------------------------------
   trg_NhatKy_KiemTraNhanVien — RB16: nhân viên không xử lý đơn do chính mình đặt
   (một người dùng có thể vừa là khách hàng vừa là nhân viên).
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_NhatKy_KiemTraNhanVien
ON dbo.NHAT_KY_XU_LY_DON
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400);
    SELECT TOP (1) @Loi = CONCAT(N'Nhân viên ', i.MaNhanVien, N' không được xử lý đơn ', i.MaDonHang,
                                 N' vì đơn này do chính nhân viên đó đặt với tư cách khách hàng.')
    FROM inserted i
    JOIN dbo.NHAN_VIEN nv ON nv.MaNhanVien = i.MaNhanVien
    JOIN dbo.DON_HANG d   ON d.MaDonHang = i.MaDonHang
    WHERE nv.MaNguoiDung = d.MaKhachHang;
    IF @Loi IS NOT NULL THROW 50193, @Loi, 1;
END;
GO

/* ---------------------------------------------------------------------
   trg_ChinhSachDiem_KiemTra
   (a) Các phiên bản chính sách không chồng khoảng hiệu lực (mỗi thời điểm ≤ 1 chính sách).
   (b) Phiên bản đã được chốt bởi đơn hàng / điểm danh thì không được sửa tham số r, v, c, L
       (muốn đổi chính sách → tạo phiên bản mới) ⇒ đơn cũ không bị ảnh hưởng.
   (c) Sửa khoảng hiệu lực không được làm đơn / điểm danh đã chốt rơi ra ngoài khoảng.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_ChinhSachDiem_KiemTra
ON dbo.CHINH_SACH_DIEM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    DECLARE @Loi NVARCHAR(400);

    -- (a) chồng lấn: [Tu1, Den1) giao [Tu2, Den2) ⇔ Tu1 < Den2 AND Tu2 < Den1
    SELECT TOP (1) @Loi = CONCAT(N'Chính sách ', i.MaChinhSach, N' có khoảng hiệu lực chồng lên chính sách ',
                                 c.MaChinhSach, N'.')
    FROM inserted i
    JOIN dbo.CHINH_SACH_DIEM c ON c.MaChinhSach <> i.MaChinhSach
    WHERE i.HieuLucTu < ISNULL(c.HieuLucDen, '9999-12-31')
      AND c.HieuLucTu < ISNULL(i.HieuLucDen, '9999-12-31');
    IF @Loi IS NOT NULL THROW 50170, @Loi, 1;

    -- (b) không sửa tham số của phiên bản đã chốt
    IF UPDATE(TyLeTichDiem) OR UPDATE(GiaTriMotDiem) OR UPDATE(TyLeGiamToiDa) OR UPDATE(DiemThuongDangNhap)
    BEGIN
        SELECT TOP (1) @Loi = CONCAT(N'Chính sách ', i.MaChinhSach,
                                     N' đã được chốt cho đơn hàng hoặc điểm danh nên không được sửa tham số; hãy tạo phiên bản chính sách mới.')
        FROM inserted i
        JOIN deleted d ON d.MaChinhSach = i.MaChinhSach
        WHERE (i.TyLeTichDiem <> d.TyLeTichDiem OR i.GiaTriMotDiem <> d.GiaTriMotDiem
               OR i.TyLeGiamToiDa <> d.TyLeGiamToiDa OR i.DiemThuongDangNhap <> d.DiemThuongDangNhap)
          AND (EXISTS (SELECT 1 FROM dbo.DON_HANG dh WHERE dh.MaChinhSachDiemChot = i.MaChinhSach)
               OR EXISTS (SELECT 1 FROM dbo.DIEM_DANH_DANG_NHAP dd WHERE dd.MaChinhSachDiemChot = i.MaChinhSach));
        IF @Loi IS NOT NULL THROW 50171, @Loi, 1;
    END;

    -- (c) dữ liệu đã chốt phải còn nằm trong khoảng hiệu lực mới
    IF UPDATE(HieuLucTu) OR UPDATE(HieuLucDen)
    BEGIN
        SELECT TOP (1) @Loi = CONCAT(N'Không thể đổi khoảng hiệu lực của chính sách ', i.MaChinhSach,
                                     N': đã có đơn hàng hoặc điểm danh chốt chính sách này nằm ngoài khoảng mới.')
        FROM inserted i
        WHERE EXISTS (SELECT 1 FROM dbo.DON_HANG dh
                      WHERE dh.MaChinhSachDiemChot = i.MaChinhSach
                        AND (dh.NgayDatHang < i.HieuLucTu OR (i.HieuLucDen IS NOT NULL AND dh.NgayDatHang >= i.HieuLucDen)))
           OR EXISTS (SELECT 1 FROM dbo.DIEM_DANH_DANG_NHAP dd
                      WHERE dd.MaChinhSachDiemChot = i.MaChinhSach
                        AND (dd.ThoiDiemDangNhap < i.HieuLucTu OR (i.HieuLucDen IS NOT NULL AND dd.ThoiDiemDangNhap >= i.HieuLucDen)));
        IF @Loi IS NOT NULL THROW 50172, @Loi, 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   trg_DiemDanh_KiemTraChinhSach — chính sách chốt phải hiệu lực lúc đăng nhập
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_DiemDanh_KiemTraChinhSach
ON dbo.DIEM_DANH_DANG_NHAP
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Loi NVARCHAR(400);
    SELECT TOP (1) @Loi = CONCAT(N'Điểm danh của khách ', i.MaKhachHang, N' ngày ',
                                 CONVERT(VARCHAR(10), i.NgayTinhThuongVN, 103),
                                 N': chính sách ', i.MaChinhSachDiemChot, N' không hiệu lực tại thời điểm đăng nhập.')
    FROM inserted i
    JOIN dbo.CHINH_SACH_DIEM cs ON cs.MaChinhSach = i.MaChinhSachDiemChot
    WHERE i.ThoiDiemDangNhap < cs.HieuLucTu
       OR (cs.HieuLucDen IS NOT NULL AND i.ThoiDiemDangNhap >= cs.HieuLucDen);
    IF @Loi IS NOT NULL THROW 50173, @Loi, 1;
END;
GO
PRINT N'21: Đã tạo 7 trigger của Đại.';
GO
