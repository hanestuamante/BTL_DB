import json

from .db import query

VARIANT_KEYS = ("MaSanPham", "MaBienTheNoiBo")
VARIANT_FIELDS = (*VARIANT_KEYS, "MauSac", "KichCo", "TonKhoRieng", "GiaBanRieng")

PROCEDURES = {
    "search": (
        "dbo.sp_TimBienThe",
        ("TuKhoa", "MaDanhMuc", "MaThuongHieu", "GiaMin", "GiaMax", "ChiConHang", "SapXep"),
    ),
    "create": ("dbo.sp_ThemBienThe", VARIANT_FIELDS),
    "update": ("dbo.sp_SuaBienThe", VARIANT_FIELDS),
    "remove": ("dbo.sp_XoaBienThe", VARIANT_KEYS),
    "report": (
        "dbo.sp_ThongKeBanTheoSanPham",
        ("MaDanhMuc", "MaThuongHieu", "TuNgay", "DenNgay", "SoLuongToiThieu", "DoanhThuToiThieu"),
    ),
}

LOOKUP_QUERIES = {
    "danh-muc": "SELECT MaDanhMuc AS id, TenDanhMuc AS ten FROM dbo.DANH_MUC ORDER BY ten, id",
    "thuong-hieu": "SELECT MaThuongHieu AS id, TenThuongHieu AS ten FROM dbo.THUONG_HIEU ORDER BY ten, id",
    "san-pham": "SELECT MaSanPham AS id, TenSanPham AS ten FROM dbo.SAN_PHAM ORDER BY ten, id",
}


def run_procedure(operation, values):
    name, fields = PROCEDURES[operation]
    # Tên thủ tục và tham số lấy từ hằng số, giá trị truyền riêng cho pymssql.
    # Tên trường gửi từ web trùng tên tham số của thủ tục.
    assignments = ", ".join(f"@{field}=%s" for field in fields)
    params = tuple(values[field] for field in fields)
    return query(f"EXEC {name} {assignments}", params, procedure=name)


def ping():
    query("SELECT 1 AS ok")


def lookup(name):
    return query(LOOKUP_QUERIES[name])


def order_total(order_id):
    return query(
        """SELECT dbo.fn_TinhTongThanhToan(d.MaDonHang) AS tongThanhToan,
                  v.TongTienHang AS tongTienHang, v.GiamVoucher AS giamVoucher,
                  v.DiemSuDung AS diemSuDung, v.GiamBangDiem AS giamBangDiem,
                  v.PhiVanChuyen AS phiVanChuyen
           FROM (VALUES (%s)) AS d(MaDonHang)
           LEFT JOIN dbo.vw_TienDonHang AS v ON v.MaDonHang = d.MaDonHang""",
        (order_id,),
    )[0]


def list_customers():
    return query(
        """SELECT kh.MaNguoiDung AS id, CONCAT(nd.Ho, N' ', nd.Ten) AS ten
           FROM dbo.KHACH_HANG AS kh
           JOIN dbo.NGUOI_DUNG AS nd ON nd.MaNguoiDung = kh.MaNguoiDung
           ORDER BY nd.Ten, nd.Ho, kh.MaNguoiDung"""
    )


def customer_points(customer_id):
    return query(
        "SELECT dbo.fn_TinhDiemKhaDung(%s) AS diemKhaDung",
        (customer_id,),
    )[0]["diemKhaDung"]


# Trang đặt hàng đóng vai khách hàng có sẵn: Nguyễn Văn An.
DEMO_CUSTOMER_ID = 1


def order_form():
    customer = query(
        """SELECT MaNguoiDung AS id, CONCAT(Ho, N' ', Ten) AS ten
           FROM dbo.NGUOI_DUNG WHERE MaNguoiDung = %s""",
        (DEMO_CUSTOMER_ID,),
    )[0]
    return {
        "khachHang": {**customer, "diemKhaDung": customer_points(DEMO_CUSTOMER_ID)},
        "diaChi": query(
            """SELECT MaDiaChi AS id,
                      CONCAT(TenNguoiNhan, N' · ', SoNha, N' ', TenDuong, N', ', Phuong, N', ', TinhThanhPho) AS ten
               FROM dbo.DIA_CHI WHERE MaKhachHang = %s ORDER BY LaMacDinh DESC, MaDiaChi""",
            (DEMO_CUSTOMER_ID,),
        ),
        "gioHang": query(
            """SELECT MaSanPham AS maSanPham, MaBienTheNoiBo AS maBienTheNoiBo, SoLuongDuMua AS soLuong
               FROM dbo.GIO_HANG WHERE MaKhachHang = %s ORDER BY MaSanPham, MaBienTheNoiBo""",
            (DEMO_CUSTOMER_ID,),
        ),
        "bienThe": query(
            """SELECT b.MaSanPham AS maSanPham, b.MaBienTheNoiBo AS maBienTheNoiBo,
                      CONCAT(s.TenSanPham, N' · ', b.MauSac, N' · ', b.KichCo) AS ten,
                      b.GiaBanRieng AS gia, b.TonKhoRieng AS tonKho
               FROM dbo.BIEN_THE_SAN_PHAM AS b
               JOIN dbo.SAN_PHAM AS s ON s.MaSanPham = b.MaSanPham
               ORDER BY s.TenSanPham, b.MaSanPham, b.MaBienTheNoiBo"""
        ),
        "voucher": query(
            """SELECT MaVoucher AS id, CONCAT(MaVoucher, N' · ', TenChuongTrinh) AS ten
               FROM dbo.KHUYEN_MAI ORDER BY NgayKetThuc DESC, MaVoucher"""
        ),
        "vanChuyen": query(
            """SELECT MaPhuongThucVC AS id, TenPhuongThucVC AS ten, PhiVanChuyenThamChieu AS phi
               FROM dbo.PHUONG_THUC_VAN_CHUYEN ORDER BY MaPhuongThucVC"""
        ),
        "thanhToan": query(
            """SELECT MaPhuongThucTT AS id, TenPhuongThucTT AS ten
               FROM dbo.PHUONG_THUC_THANH_TOAN ORDER BY MaPhuongThucTT"""
        ),
    }


def items_json(order):
    items = [
        {"MaSanPham": item["maSanPham"], "MaBienTheNoiBo": item["maBienTheNoiBo"], "SoLuong": item["soLuong"]}
        for item in order["matHang"]
    ]
    return json.dumps(items, ensure_ascii=False)


def preview_order(order):
    # Chỉ đọc, không ghi. Số chính thức do sp_TaoDonHang tính lại khi đặt.
    return query(
        """DECLARE @Muc NVARCHAR(MAX) = %s, @Voucher VARCHAR(20) = %s, @U INT = %s, @VC INT = %s;
           DECLARE @BayGio DATETIME2(0) = dbo.fn_ThoiDiemVN();
           DECLARE @H DECIMAL(18,2) = ISNULL((
               SELECT SUM(m.SoLuong * b.GiaBanRieng)
               FROM OPENJSON(@Muc) WITH (MaSanPham INT, MaBienTheNoiBo VARCHAR(20), SoLuong INT) AS m
               JOIN dbo.BIEN_THE_SAN_PHAM AS b
                 ON b.MaSanPham = m.MaSanPham AND b.MaBienTheNoiBo = m.MaBienTheNoiBo), 0);
           DECLARE @LoiVoucher NVARCHAR(400) =
               CASE WHEN @Voucher IS NOT NULL THEN dbo.fn_KiemTraVoucher(@Voucher, @H, @BayGio) END;
           DECLARE @V DECIMAL(18,2) = ISNULL((
               SELECT CASE WHEN GiaTriGiamGia > @H THEN @H ELSE GiaTriGiamGia END
               FROM dbo.KHUYEN_MAI WHERE MaVoucher = @Voucher AND @LoiVoucher IS NULL), 0);
           DECLARE @F DECIMAL(18,2) = ISNULL((
               SELECT PhiVanChuyenThamChieu FROM dbo.PHUONG_THUC_VAN_CHUYEN WHERE MaPhuongThucVC = @VC), 0);
           DECLARE @Diem INT = dbo.fn_TinhDiemKhaDung(%s);

           SELECT @H AS H, @V AS V, x.U, x.U * cs.GiaTriMotDiem AS G, @F AS F,
                  @H - @V - x.U * cs.GiaTriMotDiem + @F AS T,
                  @LoiVoucher AS loiVoucher, t.toiDa AS diemToiDa, @Diem AS diemKhaDung,
                  cs.GiaTriMotDiem AS giaTriMotDiem, cs.TyLeGiamToiDa * 100 AS phanTramToiDa,
                  cs.TyLeTichDiem * 100 AS phanTramTich,
                  CAST(FLOOR(cs.TyLeTichDiem * (@H - @V - x.U * cs.GiaTriMotDiem) / cs.GiaTriMotDiem) AS INT) AS diemSeNhan
           FROM dbo.CHINH_SACH_DIEM AS cs
           CROSS APPLY (SELECT FLOOR(cs.TyLeGiamToiDa * (@H - @V) / cs.GiaTriMotDiem) AS gioiHan) AS a
           CROSS APPLY (SELECT CASE WHEN @Diem < a.gioiHan THEN @Diem ELSE a.gioiHan END AS toiDa) AS t
           CROSS APPLY (SELECT CASE WHEN @U BETWEEN 0 AND t.toiDa THEN @U ELSE 0 END AS U) AS x
           WHERE cs.MaChinhSach = dbo.fn_ChinhSachHieuLuc(@BayGio)""",
        (items_json(order), order["maVoucher"], order["diemSuDung"] or 0, order["maPhuongThucVC"], DEMO_CUSTOMER_ID),
    )


def create_order(order):
    return query(
        """EXEC dbo.sp_TaoDonHang @MaKhachHang=%s, @MaDiaChi=%s, @MaPhuongThucVC=%s, @MaPhuongThucTT=%s,
                @DanhSachMuc=%s, @DanhSachVoucher=%s, @DiemSuDung=%s, @LoiNhanNguoiBan=%s""",
        (
            DEMO_CUSTOMER_ID, order["maDiaChi"], order["maPhuongThucVC"], order["maPhuongThucTT"],
            items_json(order), order["maVoucher"], order["diemSuDung"], order["loiNhan"],
        ),
        procedure="dbo.sp_TaoDonHang",
    )[0]


def manage_orders():
    return {
        "donHang": query(
            """SELECT d.MaDonHang AS id, CONVERT(CHAR(16), d.NgayDatHang, 120) AS ngayDat,
                      CONCAT(n.Ho, N' ', n.Ten) AS khachHang,
                      dbo.fn_TinhTongThanhToan(d.MaDonHang) AS tong, d.TrangThaiDon AS trangThai
               FROM dbo.DON_HANG AS d
               JOIN dbo.NGUOI_DUNG AS n ON n.MaNguoiDung = d.MaKhachHang
               ORDER BY d.NgayDatHang DESC, d.MaDonHang DESC"""
        ),
        "nhanVien": query(
            """SELECT nv.MaNhanVien AS id, CONCAT(nv.MaNhanVien, N' · ', n.Ho, N' ', n.Ten, N' · ', nv.ChucVu) AS ten
               FROM dbo.NHAN_VIEN AS nv
               JOIN dbo.NGUOI_DUNG AS n ON n.MaNguoiDung = nv.MaNguoiDung
               ORDER BY nv.MaNhanVien"""
        ),
    }


def update_status(order_id, status, source, employee=None, note=None):
    return query(
        """EXEC dbo.sp_CapNhatTrangThaiDon @MaDonHang=%s, @TrangThaiMoi=%s, @NguonThaoTac=%s,
                @MaNhanVien=%s, @GhiChu=%s""",
        (order_id, status, source, employee, note),
        procedure="dbo.sp_CapNhatTrangThaiDon",
    )[0]


def change_order_status(order_id, status, employee):
    return update_status(order_id, status, "NhanVien" if employee else "HeThong", employee)


def my_orders():
    return query(
        """SELECT d.MaDonHang AS id, CONVERT(CHAR(16), d.NgayDatHang, 120) AS ngayDat,
                  (SELECT STRING_AGG(CONCAT(sp.TenSanPham, N' (', ct.MauSacChot, N', ', ct.KichCoChot, N') × ',
                                            ct.SoLuongMua), N'; ')
                   FROM dbo.CHI_TIET_DON_HANG AS ct
                   JOIN dbo.SAN_PHAM AS sp ON sp.MaSanPham = ct.MaSanPham
                   WHERE ct.MaDonHang = d.MaDonHang) AS sanPham,
                  dbo.fn_TinhTongThanhToan(d.MaDonHang) AS tong, d.TrangThaiDon AS trangThai,
                  (SELECT COUNT(*) FROM dbo.CHI_TIET_DON_HANG AS ct
                   WHERE ct.MaDonHang = d.MaDonHang AND NOT EXISTS (
                       SELECT 1 FROM dbo.DANH_GIA AS dg
                       WHERE dg.MaDonHang = ct.MaDonHang AND dg.SoThuTuDong = ct.SoThuTuDong)) AS chuaDanhGia
           FROM dbo.DON_HANG AS d
           WHERE d.MaKhachHang = %s
           ORDER BY d.NgayDatHang DESC, d.MaDonHang DESC""",
        (DEMO_CUSTOMER_ID,),
    )


def is_my_order(order_id):
    return bool(query(
        "SELECT 1 AS ok FROM dbo.DON_HANG WHERE MaDonHang = %s AND MaKhachHang = %s",
        (order_id, DEMO_CUSTOMER_ID),
    ))


def cancel_my_order(order_id):
    return update_status(order_id, "DA_HUY", "KhachHang", note="Khách hàng tự hủy đơn")


def receive_my_order(order_id):
    # sp_CapNhatTrangThaiDon chỉ cho nhân viên chuyển sang DA_GIAO, nên ghi theo nhân viên đã bàn giao đơn.
    handlers = query(
        """SELECT TOP (1) MaNhanVien FROM dbo.NHAT_KY_XU_LY_DON
           WHERE MaDonHang = %s AND TrangThaiSau = 'DANG_GIAO' AND MaNhanVien IS NOT NULL
           ORDER BY ThoiDiem DESC""",
        (order_id,),
    )
    employee = handlers[0]["MaNhanVien"] if handlers else None
    if employee is None:
        # Chưa bàn giao: để thủ tục tự từ chối với lý do cụ thể.
        return update_status(order_id, "DA_GIAO", "KhachHang")
    return update_status(order_id, "DA_GIAO", "NhanVien", employee, "Khách hàng xác nhận đã nhận hàng trên trang Đơn của tôi")


def order_detail(order_id):
    orders = query(
        """SELECT d.MaDonHang AS id, d.TrangThaiDon AS trangThai,
                  CONVERT(CHAR(16), d.NgayDatHang, 120) AS ngayDat,
                  CONVERT(CHAR(10), d.NgayGiaoDuKien, 120) AS ngayGiaoDuKien,
                  CONCAT(n.Ho, N' ', n.Ten) AS khachHang,
                  d.TenNguoiNhan AS nguoiNhan, d.SdtNguoiNhan AS sdt, d.DiaChiGiaoHang AS diaChi,
                  vc.TenPhuongThucVC AS vanChuyen, tt.TenPhuongThucTT AS thanhToan,
                  d.LoiNhanNguoiBan AS loiNhan, cs.GiaTriMotDiem AS giaTriMotDiem
           FROM dbo.DON_HANG AS d
           JOIN dbo.NGUOI_DUNG AS n ON n.MaNguoiDung = d.MaKhachHang
           JOIN dbo.PHUONG_THUC_VAN_CHUYEN AS vc ON vc.MaPhuongThucVC = d.MaPhuongThucVC
           JOIN dbo.PHUONG_THUC_THANH_TOAN AS tt ON tt.MaPhuongThucTT = d.MaPhuongThucTT
           JOIN dbo.CHINH_SACH_DIEM AS cs ON cs.MaChinhSach = d.MaChinhSachDiemChot
           WHERE d.MaDonHang = %s""",
        (order_id,),
    )
    if not orders:
        return None
    return {
        **orders[0],
        "matHang": query(
            """SELECT ct.SoThuTuDong AS soThuTuDong, sp.TenSanPham AS ten, ct.MaBienTheNoiBo AS maBienTheNoiBo,
                      ct.MauSacChot AS mauSac, ct.KichCoChot AS kichCo,
                      ct.SoLuongMua AS soLuong, ct.DonGiaLucDat AS donGia,
                      ct.SoLuongMua * ct.DonGiaLucDat AS thanhTien,
                      dg.SoSao AS soSao, dg.NoiDungBinhLuan AS binhLuan, dg.DanhGiaDungMoTa AS dungMoTa,
                      CONVERT(CHAR(16), dg.ThoiGianDanhGia, 120) AS ngayDanhGia
               FROM dbo.CHI_TIET_DON_HANG AS ct
               JOIN dbo.SAN_PHAM AS sp ON sp.MaSanPham = ct.MaSanPham
               LEFT JOIN dbo.DANH_GIA AS dg
                 ON dg.MaDonHang = ct.MaDonHang AND dg.SoThuTuDong = ct.SoThuTuDong
               WHERE ct.MaDonHang = %s ORDER BY ct.SoThuTuDong""",
            (order_id,),
        ),
        "voucher": query(
            """SELECT a.MaVoucher AS ma, k.TenChuongTrinh AS ten, a.TienGiamChot AS tienGiam
               FROM dbo.AP_DUNG_KHUYEN_MAI AS a
               JOIN dbo.KHUYEN_MAI AS k ON k.MaVoucher = a.MaVoucher
               WHERE a.MaDonHang = %s ORDER BY a.TienGiamChot DESC, a.MaVoucher""",
            (order_id,),
        ),
        "tien": order_total(order_id),
    }


def add_review(order_id, review):
    # trg_DanhGia_KiemTraQuyen tự kiểm tra đơn đã giao hay chưa.
    query(
        """INSERT INTO dbo.DANH_GIA (SoSao, NoiDungBinhLuan, DanhGiaDungMoTa, MaDonHang, SoThuTuDong)
           VALUES (%s, %s, %s, %s, %s)""",
        (review["soSao"], review["binhLuan"], review["dungMoTa"], order_id, review["soThuTuDong"]),
    )
