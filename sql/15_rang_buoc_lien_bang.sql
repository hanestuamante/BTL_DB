/* =====================================================================
   15_rang_buoc_lien_bang.sql — T15 (Khưu Huỳnh Gia Hưng)
   Ràng buộc liên bảng không viết được bằng CHECK/UNIQUE/FK:
     sp_TaoNguoiDung                 cửa duy nhất để tạo người dùng (total specialization)
     trg_NguoiDung_KiemTra           chặn INSERT ngoài thủ tục (50223); sửa ngày sinh làm khách < 13 tuổi (50221)
     trg_KhachHang_KiemTraVaiTro     khách phải đủ 13 tuổi (50220, RB4); không mất vai trò cuối (50224); không đổi chủ vai trò (50226)
     trg_NhanVien_KiemTraVaiTro      không mất vai trò cuối (50224); không đổi chủ vai trò (50226)
     trg_DanhMuc_KhongVongLap        cây danh mục không có vòng (50240, RB9)
   Thiết kế: docs/csdl-nguoi-dung-san-pham.md mục 3, 5. Chạy SAU 11, 12, 13.

   Mã lỗi (dải của Hưng 50200 – 50399):
     50220  khách hàng chưa đủ 13 tuổi hoặc thiếu ngày sinh (khi tạo / thêm vai trò khách)
     50221  sửa NgaySinh làm một khách hàng dưới 13 tuổi hoặc mất ngày sinh
     50222  tạo người dùng mà không chọn vai trò nào
     50223  INSERT NGUOI_DUNG không qua sp_TaoNguoiDung
     50224  xóa / chuyển vai trò cuối cùng của một người dùng còn tồn tại
     50225  có MaNhanVien nhưng thiếu ChucVu / Luong / NgayVaoLam
     50226  đổi MaNguoiDung của một dòng KHACH_HANG / NHAN_VIEN (chuyển vai trò sang người khác)
     50240  danh mục tạo vòng
   "Hôm nay" theo giờ VN: CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE) (file này chạy trước 20).
   ===================================================================== */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
SET NOCOUNT ON;
GO

/* ---------------------------------------------------------------------
   sp_TaoNguoiDung — Người viết: Khưu Huỳnh Gia Hưng
   Tạo NGUOI_DUNG và ít nhất một vai trò trong cùng một giao dịch.
   Có vai trò nhân viên khi và chỉ khi @MaNhanVien khác NULL. Không trả về bảng kết quả.
   Đánh dấu bằng SESSION_CONTEXT(N'BTL2_TaoNguoiDung') = mã của giao dịch hiện tại, để
   trg_NguoiDung_KiemTra biết lệnh INSERT đi qua thủ tục này. Gắn với mã giao dịch nên nếu lệnh gọi
   bị hủy giữa chừng (hết thời gian chờ) mà CATCH không kịp xóa cờ, cờ còn sót cũng không khớp với
   giao dịch sau. Lưu ý: người có quyền tự gọi sp_set_session_context vẫn giả được cờ; trong phạm vi
   bài, mọi ứng dụng tạo người dùng qua thủ tục này.
   --------------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE dbo.sp_TaoNguoiDung
    @MaNguoiDung   INT,
    @TenDangNhap   VARCHAR(50),
    @MatKhauBam    VARCHAR(255),
    @Ho            NVARCHAR(50),
    @Ten           NVARCHAR(50),
    @Email         VARCHAR(100),
    @SdtXacThuc    VARCHAR(15),
    @GioiTinh      NVARCHAR(10),
    @NgaySinh      DATE,
    @LaKhachHang   BIT,
    @MaNhanVien    VARCHAR(10)    = NULL,
    @ChucVu        NVARCHAR(50)   = NULL,
    @Luong         DECIMAL(14,2)  = NULL,
    @NgayVaoLam    DATE           = NULL,
    @AnhDaiDien    VARCHAR(255)   = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF ISNULL(@LaKhachHang, 0) = 0 AND @MaNhanVien IS NULL
        THROW 50222, N'Người dùng phải có ít nhất một vai trò: khách hàng (@LaKhachHang = 1) hoặc nhân viên (@MaNhanVien).', 1;
    IF @MaNhanVien IS NOT NULL AND (@ChucVu IS NULL OR @Luong IS NULL OR @NgayVaoLam IS NULL)
        THROW 50225, N'Nhân viên phải có đủ chức vụ, lương và ngày vào làm.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @MaGiaoDich BIGINT = CURRENT_TRANSACTION_ID();
        EXEC sys.sp_set_session_context @key = N'BTL2_TaoNguoiDung', @value = @MaGiaoDich;

        INSERT dbo.NGUOI_DUNG (MaNguoiDung, TenDangNhap, MatKhauBam, Ho, Ten, Email, SdtXacThuc, GioiTinh, NgaySinh, AnhDaiDien)
        VALUES (@MaNguoiDung, @TenDangNhap, @MatKhauBam, @Ho, @Ten, @Email, @SdtXacThuc, @GioiTinh, @NgaySinh, @AnhDaiDien);

        IF @LaKhachHang = 1
            INSERT dbo.KHACH_HANG (MaNguoiDung) VALUES (@MaNguoiDung);
        IF @MaNhanVien IS NOT NULL
            INSERT dbo.NHAN_VIEN (MaNguoiDung, MaNhanVien, ChucVu, Luong, NgayVaoLam)
            VALUES (@MaNguoiDung, @MaNhanVien, @ChucVu, @Luong, @NgayVaoLam);

        EXEC sys.sp_set_session_context @key = N'BTL2_TaoNguoiDung', @value = NULL;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC sys.sp_set_session_context @key = N'BTL2_TaoNguoiDung', @value = NULL;   -- session context không bị ROLLBACK
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------
   trg_NguoiDung_KiemTra — Người viết: Khưu Huỳnh Gia Hưng
   INSERT: chỉ cho phép khi đi qua sp_TaoNguoiDung (50223).
   UPDATE NgaySinh: mọi người dùng là khách hàng phải còn ngày sinh và đủ 13 tuổi (50221).
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_NguoiDung_KiemTra
ON dbo.NGUOI_DUNG
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;

    IF NOT EXISTS (SELECT 1 FROM deleted)
       AND ISNULL(CAST(SESSION_CONTEXT(N'BTL2_TaoNguoiDung') AS BIGINT), -1) <> CURRENT_TRANSACTION_ID()
        THROW 50223, N'Không được thêm thẳng vào NGUOI_DUNG. Hãy tạo người dùng bằng dbo.sp_TaoNguoiDung để luôn có ít nhất một vai trò.', 1;

    IF UPDATE(NgaySinh)
    BEGIN
        DECLARE @Ma INT, @Loi NVARCHAR(400);
        DECLARE @MocNgaySinh DATE = DATEADD(YEAR, -13, CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE));
        SELECT TOP (1) @Ma = i.MaNguoiDung
        FROM inserted i
        JOIN dbo.KHACH_HANG k ON k.MaNguoiDung = i.MaNguoiDung
        WHERE i.NgaySinh IS NULL OR i.NgaySinh > @MocNgaySinh;
        IF @Ma IS NOT NULL
        BEGIN
            SET @Loi = CONCAT(N'Không thể sửa ngày sinh của người dùng ', @Ma,
                              N': khách hàng phải có ngày sinh và sinh trước hoặc đúng ngày ',
                              CONVERT(VARCHAR(10), @MocNgaySinh, 103), N' (đủ 13 tuổi).');
            THROW 50221, @Loi, 1;
        END;
    END;
END;
GO

/* ---------------------------------------------------------------------
   trg_KhachHang_KiemTraVaiTro — Người viết: Khưu Huỳnh Gia Hưng
   Không cho đổi MaNguoiDung của dòng vai trò, tức chuyển vai trò sang người khác (50226).
   Dòng mới (INSERT): người dùng phải có ngày sinh và đủ 13 tuổi (50220, RB4).
   Dòng mất đi (DELETE): người dùng còn tồn tại thì phải còn ít nhất một vai trò (50224).
   Khi xóa hẳn người dùng, dòng NGUOI_DUNG đã mất trước lúc trigger chạy nên không báo lỗi.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_KhachHang_KiemTraVaiTro
ON dbo.KHACH_HANG
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaTuoi INT, @MaMatVaiTro INT, @Loi NVARCHAR(400);
    DECLARE @MocNgaySinh DATE = DATEADD(YEAR, -13, CAST(DATEADD(HOUR, 7, SYSUTCDATETIME()) AS DATE));

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
       AND EXISTS (SELECT 1 FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.MaNguoiDung = i.MaNguoiDung))
        THROW 50226, N'Không được đổi MaNguoiDung của vai trò khách hàng. Muốn đổi người thì xóa dòng cũ và tạo vai trò mới cho người kia.', 1;

    SELECT TOP (1) @MaTuoi = i.MaNguoiDung
    FROM inserted i
    JOIN dbo.NGUOI_DUNG n ON n.MaNguoiDung = i.MaNguoiDung
    WHERE n.NgaySinh IS NULL OR n.NgaySinh > @MocNgaySinh;
    IF @MaTuoi IS NOT NULL
    BEGIN
        SET @Loi = CONCAT(N'Người dùng ', @MaTuoi, N' không thể là khách hàng: cần có ngày sinh và sinh trước hoặc đúng ngày ',
                          CONVERT(VARCHAR(10), @MocNgaySinh, 103), N' (đủ 13 tuổi).');
        THROW 50220, @Loi, 1;
    END;

    SELECT TOP (1) @MaMatVaiTro = d.MaNguoiDung
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.NGUOI_DUNG n WHERE n.MaNguoiDung = d.MaNguoiDung)
      AND NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG k WHERE k.MaNguoiDung = d.MaNguoiDung)
      AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN v WHERE v.MaNguoiDung = d.MaNguoiDung);
    IF @MaMatVaiTro IS NOT NULL
    BEGIN
        SET @Loi = CONCAT(N'Người dùng ', @MaMatVaiTro,
                          N' sẽ không còn vai trò nào. Mỗi người dùng phải là khách hàng hoặc nhân viên; muốn bỏ hẳn thì xóa dòng NGUOI_DUNG.');
        THROW 50224, @Loi, 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   trg_NhanVien_KiemTraVaiTro — Người viết: Khưu Huỳnh Gia Hưng
   Không cho đổi MaNguoiDung của dòng nhân viên (50226): NHAT_KY_XU_LY_DON ghi theo MaNhanVien,
   nên chuyển mã nhân viên sang người khác sẽ làm sai lịch sử (RB16: nhân viên không xử lý đơn của chính mình).
   Dòng mất đi (DELETE): người dùng còn tồn tại thì phải còn ít nhất một vai trò (50224).
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_NhanVien_KiemTraVaiTro
ON dbo.NHAN_VIEN
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @MaMatVaiTro INT, @Loi NVARCHAR(400);

    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
       AND EXISTS (SELECT 1 FROM inserted i WHERE NOT EXISTS (SELECT 1 FROM deleted d WHERE d.MaNguoiDung = i.MaNguoiDung))
        THROW 50226, N'Không được đổi MaNguoiDung của nhân viên: nhật ký xử lý đơn ghi theo mã nhân viên nên lịch sử sẽ sai. Hãy tạo mã nhân viên mới cho người kia.', 1;

    SELECT TOP (1) @MaMatVaiTro = d.MaNguoiDung
    FROM deleted d
    WHERE EXISTS (SELECT 1 FROM dbo.NGUOI_DUNG n WHERE n.MaNguoiDung = d.MaNguoiDung)
      AND NOT EXISTS (SELECT 1 FROM dbo.KHACH_HANG k WHERE k.MaNguoiDung = d.MaNguoiDung)
      AND NOT EXISTS (SELECT 1 FROM dbo.NHAN_VIEN v WHERE v.MaNguoiDung = d.MaNguoiDung);
    IF @MaMatVaiTro IS NOT NULL
    BEGIN
        SET @Loi = CONCAT(N'Người dùng ', @MaMatVaiTro,
                          N' sẽ không còn vai trò nào. Mỗi người dùng phải là khách hàng hoặc nhân viên; muốn bỏ hẳn thì xóa dòng NGUOI_DUNG.');
        THROW 50224, @Loi, 1;
    END;
END;
GO

/* ---------------------------------------------------------------------
   trg_DanhMuc_KhongVongLap — Người viết: Khưu Huỳnh Gia Hưng
   Với mỗi danh mục vừa thêm / sửa có cha, đi ngược chuỗi cha trên bảng SAU khi sửa (CTE đệ quy).
   Gặp lại chính danh mục ban đầu ⇒ có vòng (50240). Đúng cả khi một câu lệnh sửa nhiều dòng.
   Độ sâu dò tối đa bằng số danh mục trong bảng: mọi vòng đều ngắn hơn số đó nên vòng dài
   bao nhiêu cũng bị bắt, và phép dò luôn dừng (MAXRECURSION 0 bỏ giới hạn mặc định 100).
   Tự trỏ (cha = chính nó) đã bị CK_DANH_MUC_KhongTuTroCha chặn trước.
   --------------------------------------------------------------------- */
CREATE OR ALTER TRIGGER dbo.trg_DanhMuc_KhongVongLap
ON dbo.DANH_MUC
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE MaDanhMucCha IS NOT NULL) RETURN;

    DECLARE @Ma INT, @Loi NVARCHAR(400), @SoDanhMuc INT = (SELECT COUNT(*) FROM dbo.DANH_MUC);
    WITH ChuoiCha (Goc, Cha, DoSau) AS (
        SELECT i.MaDanhMuc, i.MaDanhMucCha, 1
        FROM inserted i
        WHERE i.MaDanhMucCha IS NOT NULL
        UNION ALL
        SELECT c.Goc, d.MaDanhMucCha, c.DoSau + 1
        FROM ChuoiCha c
        JOIN dbo.DANH_MUC d ON d.MaDanhMuc = c.Cha
        WHERE d.MaDanhMucCha IS NOT NULL
          AND c.Cha <> c.Goc
          AND c.DoSau < @SoDanhMuc
    )
    SELECT TOP (1) @Ma = Goc FROM ChuoiCha WHERE Cha = Goc
    OPTION (MAXRECURSION 0);

    IF @Ma IS NOT NULL
    BEGIN
        SET @Loi = CONCAT(N'Không thể đặt danh mục cha cho danh mục ', @Ma,
                          N': cây danh mục sẽ có vòng lặp (một danh mục không được là cha, trực tiếp hay gián tiếp, của chính nó).');
        THROW 50240, @Loi, 1;
    END;
END;
GO
PRINT N'15: Đã tạo sp_TaoNguoiDung và 4 trigger ràng buộc liên bảng.';
GO
