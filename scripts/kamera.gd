class_name Kamera
extends Camera2D


func _ready() -> void:
	# Hubungkan sinyal saat kamera siap, karena level baru dimuat setelah permainan mulai.
	GameManager.level_changed.connect(_on_level_changed)


func _on_level_changed(_level_index: int) -> void:
	# Cari peta yang baru dimuat setelah GameManager memberi tahu pergantian level.
	var peta: TileMapLayer = get_tree().get_first_node_in_group("peta") as TileMapLayer
	# Berhenti jika peta tidak ditemukan agar batas kamera tidak memakai data kosong.
	if peta == null:
		push_warning("Peta tidak ditemukan! Cek group 'peta' di level ini.")
		return

	# Ambil area tile yang terpakai dan ukuran setiap tile dalam piksel lokal.
	var area: Rect2i = peta.get_used_rect()
	var tile_size: Vector2i = peta.tile_set.tile_size
	# Kalikan koordinat tile dengan ukuran tile untuk mengubahnya menjadi piksel lokal.
	var posisi_kiri_atas: Vector2 = Vector2(area.position * tile_size)
	var posisi_kanan_bawah: Vector2 = Vector2(area.end * tile_size)
	# Ubah posisi lokal ke global agar skala level 3x ikut dihitung dengan benar.
	var kiri_atas: Vector2 = peta.to_global(posisi_kiri_atas)
	var kanan_bawah: Vector2 = peta.to_global(posisi_kanan_bawah)
	# Pasang batas kamera pada tepi peta dalam koordinat global.
	var kiri: int = int(kiri_atas.x)
	var atas: int = int(kiri_atas.y)
	var kanan: int = int(kanan_bawah.x)
	var bawah: int = int(kanan_bawah.y)
	limit_left = kiri
	limit_top = atas
	limit_right = kanan
	limit_bottom = bawah
	# Hentikan gerakan smoothing lama agar kamera langsung menyesuaikan spawn baru.
	reset_smoothing()
	# Tampilkan angka batas kamera untuk memastikan ukuran peta sudah terbaca.
	print("Batas kamera: ", kiri, ", ", atas, ", ", kanan, ", ", bawah)
