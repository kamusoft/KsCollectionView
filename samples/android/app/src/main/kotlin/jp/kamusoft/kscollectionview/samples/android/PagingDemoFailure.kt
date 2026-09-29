package jp.kamusoft.kscollectionview.samples.android

/** 「ページング」画面の偽の取得元が、「次の読み込みを失敗させる」がオンの間に投げる失敗。 */
class PagingDemoFailure : Exception("読み込みを失敗させる設定のため失敗しました")
