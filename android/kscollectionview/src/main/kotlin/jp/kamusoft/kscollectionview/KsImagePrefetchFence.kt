package jp.kamusoft.kscollectionview

import java.lang.ref.WeakReference

/** キャッシュ操作の直前に進行中の先読みを止めるための受け口。 */
internal interface KsImagePrefetchFencing {
    /** 台帳に残っている取得をすべて止め、台帳も空にする。 */
    fun fenceAll()

    /** 指定した識別子の画像の取得だけを、幅に関わらずすべて止め、台帳から外す。 */
    fun fence(identifier: String)
}

/**
 * 生存している先読み窓の名簿。キャッシュを消すときに、消す前に始まった取得が消した後で
 * キャッシュへ書き戻すのを防ぐために使う。
 *
 * 参照は弱く持つため、コレクションが破棄されれば名簿からも自然に消える。
 */
internal object KsImagePrefetchRegistry {
    private val entries = mutableListOf<WeakReference<KsImagePrefetchFencing>>()

    fun register(target: KsImagePrefetchFencing) {
        synchronized(entries) {
            entries.removeAll { it.get() == null || it.get() === target }
            entries.add(WeakReference(target))
        }
    }

    /** 進行中の取得をすべて止める。範囲を指定したキャッシュの消去で使う。 */
    fun fenceAll() {
        for (target in liveTargets()) {
            target.fenceAll()
        }
    }

    /** 指定した識別子の画像の取得だけを止める。ソース単位の削除で使う。 */
    fun fence(identifier: String) {
        for (target in liveTargets()) {
            target.fence(identifier)
        }
    }

    private fun liveTargets(): List<KsImagePrefetchFencing> = synchronized(entries) {
        entries.removeAll { it.get() == null }
        entries.mapNotNull { it.get() }
    }
}
