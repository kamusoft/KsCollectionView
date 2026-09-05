# 証跡: トランザクション引き渡し spike のフレームログ

環境: Simulator iPhone 17 Pro / iOS 26.5、Debug 構成。`--verify-height-change` で検証画面「行の高さ変化」を開き、親 state 経路の行 1 を 1 回タップしたときの記録。
`cellPresent` は行のセルの presentation layer の高さ、`contentPresent` は content view の presentation layer の高さ (pt)。

## 構成 A (引き渡しなし・タップそのまま)

```
[spike] transaction.animation=nil disablesAnimations=false
[spike] transaction.animation=nil disablesAnimations=false
[spike-frame] t=0.021 cellModel=141.7 cellPresent=48.6 contentModel=141.7 contentPresent=48.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.038 cellModel=141.7 cellPresent=58.8 contentModel=141.7 contentPresent=58.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.055 cellModel=141.7 cellPresent=71.1 contentModel=141.7 contentPresent=71.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.071 cellModel=141.7 cellPresent=83.3 contentModel=141.7 contentPresent=83.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.088 cellModel=141.7 cellPresent=94.4 contentModel=141.7 contentPresent=94.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.105 cellModel=141.7 cellPresent=104.1 contentModel=141.7 contentPresent=104.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.121 cellModel=141.7 cellPresent=112.1 contentModel=141.7 contentPresent=112.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.138 cellModel=141.7 cellPresent=118.7 contentModel=141.7 contentPresent=118.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.155 cellModel=141.7 cellPresent=124.0 contentModel=141.7 contentPresent=124.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.171 cellModel=141.7 cellPresent=128.2 contentModel=141.7 contentPresent=128.2 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.188 cellModel=141.7 cellPresent=131.4 contentModel=141.7 contentPresent=131.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.205 cellModel=141.7 cellPresent=133.9 contentModel=141.7 contentPresent=133.9 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.221 cellModel=141.7 cellPresent=135.8 contentModel=141.7 contentPresent=135.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.238 cellModel=141.7 cellPresent=137.3 contentModel=141.7 contentPresent=137.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.255 cellModel=141.7 cellPresent=138.4 contentModel=141.7 contentPresent=138.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.271 cellModel=141.7 cellPresent=139.2 contentModel=141.7 contentPresent=139.2 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.288 cellModel=141.7 cellPresent=139.9 contentModel=141.7 contentPresent=139.9 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.305 cellModel=141.7 cellPresent=140.3 contentModel=141.7 contentPresent=140.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.321 cellModel=141.7 cellPresent=140.7 contentModel=141.7 contentPresent=140.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.338 cellModel=141.7 cellPresent=140.9 contentModel=141.7 contentPresent=140.9 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.355 cellModel=141.7 cellPresent=141.1 contentModel=141.7 contentPresent=141.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.371 cellModel=141.7 cellPresent=141.3 contentModel=141.7 contentPresent=141.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.388 cellModel=141.7 cellPresent=141.4 contentModel=141.7 contentPresent=141.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.405 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.421 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.438 cellModel=141.7 cellPresent=141.6 contentModel=141.7 contentPresent=141.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.455 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.471 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.488 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.505 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.521 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.538 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.555 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.571 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.588 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.605 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.621 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.638 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.655 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.671 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
jp.kamusoft.kscollectionview.samples.ios: 19411
```

## 構成 B (withTransaction・タップそのまま)

```
[spike] transaction.animation=nil disablesAnimations=false
[spike] transaction.animation=nil disablesAnimations=false
[spike-frame] t=0.013 cellModel=141.7 cellPresent=45.2 contentModel=141.7 contentPresent=45.2 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.030 cellModel=141.7 cellPresent=52.8 contentModel=141.7 contentPresent=52.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.047 cellModel=141.7 cellPresent=64.3 contentModel=141.7 contentPresent=64.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.063 cellModel=141.7 cellPresent=76.7 contentModel=141.7 contentPresent=76.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.080 cellModel=141.7 cellPresent=88.5 contentModel=141.7 contentPresent=88.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.097 cellModel=141.7 cellPresent=99.0 contentModel=141.7 contentPresent=99.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.113 cellModel=141.7 cellPresent=107.9 contentModel=141.7 contentPresent=107.9 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.130 cellModel=141.7 cellPresent=115.3 contentModel=141.7 contentPresent=115.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.147 cellModel=141.7 cellPresent=121.3 contentModel=141.7 contentPresent=121.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.163 cellModel=141.7 cellPresent=126.0 contentModel=141.7 contentPresent=126.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.180 cellModel=141.7 cellPresent=129.7 contentModel=141.7 contentPresent=129.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.197 cellModel=141.7 cellPresent=132.6 contentModel=141.7 contentPresent=132.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.213 cellModel=141.7 cellPresent=134.8 contentModel=141.7 contentPresent=134.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.230 cellModel=141.7 cellPresent=136.5 contentModel=141.7 contentPresent=136.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.247 cellModel=141.7 cellPresent=137.8 contentModel=141.7 contentPresent=137.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.263 cellModel=141.7 cellPresent=138.8 contentModel=141.7 contentPresent=138.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.280 cellModel=141.7 cellPresent=139.5 contentModel=141.7 contentPresent=139.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.297 cellModel=141.7 cellPresent=140.1 contentModel=141.7 contentPresent=140.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.313 cellModel=141.7 cellPresent=140.5 contentModel=141.7 contentPresent=140.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.330 cellModel=141.7 cellPresent=140.8 contentModel=141.7 contentPresent=140.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.347 cellModel=141.7 cellPresent=141.0 contentModel=141.7 contentPresent=141.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.363 cellModel=141.7 cellPresent=141.2 contentModel=141.7 contentPresent=141.2 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.380 cellModel=141.7 cellPresent=141.3 contentModel=141.7 contentPresent=141.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.397 cellModel=141.7 cellPresent=141.4 contentModel=141.7 contentPresent=141.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.413 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.430 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.447 cellModel=141.7 cellPresent=141.6 contentModel=141.7 contentPresent=141.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.480 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.497 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.513 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.530 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.547 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.563 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.580 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.597 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.613 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.630 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.647 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.663 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.680 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
jp.kamusoft.kscollectionview.samples.ios: 18884
```

## 構成 C (withTransaction・タップを withAnimation で包む)

```
[spike] transaction.animation=nil disablesAnimations=false
[spike] transaction.animation=Optional(AnyAnimator(SwiftUI.DefaultAnimation())) disablesAnimations=false
[spike-frame] t=0.028 cellModel=141.7 cellPresent=52.8 contentModel=141.7 contentPresent=52.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.045 cellModel=141.7 cellPresent=64.3 contentModel=141.7 contentPresent=64.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.062 cellModel=141.7 cellPresent=76.7 contentModel=141.7 contentPresent=76.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.078 cellModel=141.7 cellPresent=88.6 contentModel=141.7 contentPresent=88.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.095 cellModel=141.7 cellPresent=99.1 contentModel=141.7 contentPresent=99.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.112 cellModel=141.7 cellPresent=108.0 contentModel=141.7 contentPresent=108.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.128 cellModel=141.7 cellPresent=115.3 contentModel=141.7 contentPresent=115.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.145 cellModel=141.7 cellPresent=121.3 contentModel=141.7 contentPresent=121.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.162 cellModel=141.7 cellPresent=126.0 contentModel=141.7 contentPresent=126.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.178 cellModel=141.7 cellPresent=129.7 contentModel=141.7 contentPresent=129.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.195 cellModel=141.7 cellPresent=132.6 contentModel=141.7 contentPresent=132.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.212 cellModel=141.7 cellPresent=134.8 contentModel=141.7 contentPresent=134.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.228 cellModel=141.7 cellPresent=136.5 contentModel=141.7 contentPresent=136.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.245 cellModel=141.7 cellPresent=137.8 contentModel=141.7 contentPresent=137.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.262 cellModel=141.7 cellPresent=138.8 contentModel=141.7 contentPresent=138.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.278 cellModel=141.7 cellPresent=139.5 contentModel=141.7 contentPresent=139.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.295 cellModel=141.7 cellPresent=140.1 contentModel=141.7 contentPresent=140.1 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.312 cellModel=141.7 cellPresent=140.5 contentModel=141.7 contentPresent=140.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.328 cellModel=141.7 cellPresent=140.8 contentModel=141.7 contentPresent=140.8 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.345 cellModel=141.7 cellPresent=141.0 contentModel=141.7 contentPresent=141.0 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.362 cellModel=141.7 cellPresent=141.2 contentModel=141.7 contentPresent=141.2 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.378 cellModel=141.7 cellPresent=141.3 contentModel=141.7 contentPresent=141.3 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.395 cellModel=141.7 cellPresent=141.4 contentModel=141.7 contentPresent=141.4 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.412 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.428 cellModel=141.7 cellPresent=141.5 contentModel=141.7 contentPresent=141.5 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.445 cellModel=141.7 cellPresent=141.6 contentModel=141.7 contentPresent=141.6 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.462 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.478 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.495 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.512 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.528 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.545 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.562 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.578 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.595 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.612 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.628 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.645 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.662 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
[spike-frame] t=0.678 cellModel=141.7 cellPresent=141.7 contentModel=141.7 contentPresent=141.7 innerModel=-1.0 innerPresent=-1.0 subviews=0
jp.kamusoft.kscollectionview.samples.ios: 19891
```

