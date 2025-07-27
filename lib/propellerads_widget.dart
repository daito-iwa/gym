import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// PropellerAds広告を表示するためのウィジェット
class PropellerAdsWidget extends StatefulWidget {
  final String zoneId;
  final PropellerAdType adType;
  final double? width;
  final double? height;
  
  const PropellerAdsWidget({
    Key? key,
    required this.zoneId,
    required this.adType,
    this.width,
    this.height,
  }) : super(key: key);
  
  @override
  State<PropellerAdsWidget> createState() => _PropellerAdsWidgetState();
}

class _PropellerAdsWidgetState extends State<PropellerAdsWidget> {
  late String _viewId;
  
  @override
  void initState() {
    super.initState();
    _viewId = 'propeller-${widget.zoneId}-${DateTime.now().millisecondsSinceEpoch}';
    _registerViewFactory();
  }
  
  void _registerViewFactory() {
    if (kIsWeb) {
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => _createPropellerElement(),
      );
    }
  }
  
  html.DivElement _createPropellerElement() {
    final div = html.DivElement();
    
    switch (widget.adType) {
      case PropellerAdType.banner:
        _createBannerAd(div);
        break;
      case PropellerAdType.popunder:
        _createPopunderAd(div);
        break;
      case PropellerAdType.push:
        _createPushAd(div);
        break;
      case PropellerAdType.inPage:
        _createInPageAd(div);
        break;
      case PropellerAdType.interstitial:
        _createInterstitialAd(div);
        break;
    }
    
    return div;
  }
  
  void _createBannerAd(html.DivElement div) {
    div.style.width = '${widget.width ?? 300}px';
    div.style.height = '${widget.height ?? 250}px';
    div.style.textAlign = 'center';
    
    final script = html.ScriptElement();
    script.type = 'text/javascript';
    script.text = '''
      (function(){
        var d = document,
        s = d.createElement('script'),
        l = d.scripts[d.scripts.length - 1];
        s.settings = '${widget.zoneId}';
        s.src = "//cdn.propellerads.com/ads?settings=" + s.settings + "&t=" + Math.random();
        s.async = true;
        l.parentNode.insertBefore(s, l);
      })();
    ''';
    
    div.append(script);
  }
  
  void _createPopunderAd(html.DivElement div) {
    final script = html.ScriptElement();
    script.type = 'text/javascript';
    script.text = '''
      (function(d,z,s){
        s.src='//'+d+'/ads/'+z+'/propu.js';
        try{(document.body||document.documentElement).appendChild(s)}catch(e){}
      })('cdn.propellerads.com', '${widget.zoneId}', document.createElement('script'));
    ''';
    
    div.append(script);
  }
  
  void _createPushAd(html.DivElement div) {
    final script = html.ScriptElement();
    script.type = 'text/javascript';
    script.text = '''
      (function(d,z,s){
        s.src='//'+d+'/ads/'+z+'/push.js';
        try{(document.body||document.documentElement).appendChild(s)}catch(e){}
      })('cdn.propellerads.com', '${widget.zoneId}', document.createElement('script'));
    ''';
    
    div.append(script);
  }
  
  void _createInPageAd(html.DivElement div) {
    div.style.width = '100%';
    div.style.height = '${widget.height ?? 250}px';
    
    final script = html.ScriptElement();
    script.type = 'text/javascript';
    script.text = '''
      (function(d,z,s){
        s.src='//'+d+'/ads/'+z+'/inpage.js';
        try{(document.body||document.documentElement).appendChild(s)}catch(e){}
      })('cdn.propellerads.com', '${widget.zoneId}', document.createElement('script'));
    ''';
    
    div.append(script);
  }
  
  void _createInterstitialAd(html.DivElement div) {
    div.style.position = 'fixed';
    div.style.top = '0';
    div.style.left = '0';
    div.style.width = '100%';
    div.style.height = '100%';
    div.style.zIndex = '9999';
    div.style.backgroundColor = 'rgba(0,0,0,0.8)';
    
    final script = html.ScriptElement();
    script.type = 'text/javascript';
    script.text = '''
      (function(d,z,s){
        s.src='//'+d+'/ads/'+z+'/interstitial.js';
        try{(document.body||document.documentElement).appendChild(s)}catch(e){}
      })('cdn.propellerads.com', '${widget.zoneId}', document.createElement('script'));
    ''';
    
    div.append(script);
  }
  
  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: HtmlElementView(viewType: _viewId),
      );
    } else {
      return Container(
        width: widget.width ?? 300,
        height: widget.height ?? 250,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: Text('Web Only Ad'),
        ),
      );
    }
  }
}

enum PropellerAdType {
  banner,      // バナー広告
  popunder,    // ポップアンダー
  push,        // プッシュ通知
  inPage,      // インページ
  interstitial // インタースティシャル
}

/// PropellerAds設定
class PropellerAdsConfig {
  // プレースホルダーID（実際のゾーンIDに置き換えてください）
  static const String bannerZoneId = '7891234';
  static const String popunderZoneId = '7891235';
  static const String pushZoneId = '7891236';
  static const String inPageZoneId = '7891237';
  static const String interstitialZoneId = '7891238';
}